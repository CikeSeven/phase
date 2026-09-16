package app.xiangyue.phase.execution

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import app.xiangyue.phase.files.AppFileDriver
import app.xiangyue.phase.accessibility.PhaseAccessibilityService
import app.xiangyue.phase.accessibility.DeviceActionQueue
import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.applications.ApplicationCatalogRestricted
import app.xiangyue.phase.applications.ApplicationListPermissionRequired
import app.xiangyue.phase.applications.ApplicationAccess

class ExecutionCoordinator(private val context: Context, private val flutter: ExecutionFlutterApi) : ExecutionHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val files = AppFileDriver(context)
    private val applications = ApplicationCatalog(context)
    val setup = ExecutionSetup(context, files, applications, ::updateApplicationPolicy)
    private var session: ExecutionSession? = null
    private var currentAppPolicy: ApplicationPolicy? = null
    private var activeTargetPackage: String? = null
    private val deviceQueue = DeviceActionQueue()
    private var deviceActive = false
    private var launching = false
    private var overlaySuppressed = false
    private val fileActions = setOf(ExecutionAction.READ_FILE, ExecutionAction.WRITE_FILE, ExecutionAction.LIST_FILES)
    private val visualActions = setOf(ExecutionAction.CAPTURE_SCREEN, ExecutionAction.PERFORM_GESTURES)
    private val tasks = NativeExecutionTasks(scope, ExecutionAction.entries.associateWith { action ->
        NativeAction { request, progress ->
            if (action in fileActions) files.execute(request, session?.fileUris ?: emptyList())
            else if (action == ExecutionAction.LIST_APPS) listApplications(request)
            else executeUi(request, progress)
        }
    }) { progress ->
        send { flutter.progress(progress) }
    }
    private var resumed = false
    private var service: ExecutionService? = null
    private var starting: CompletableDeferred<HostReply>? = null
    private var confirmationExpiry: Job? = null
    // Only transient presentation state. ToolExecutor/Drift remains the business source of truth.
    var confirmation: ExecutionConfirmation? = null
        private set

    override suspend fun execute(request: ExecutionRequest): ExecutionResult = tasks.execute(request)
    override fun cancel(toolCallId: String) = tasks.cancel(toolCallId)

    override fun queryCapabilities(): ExecutionCapabilities {
        val manager = context.getSystemService(NotificationManager::class.java)
        val channelEnabled = Build.VERSION.SDK_INT < 26 ||
            manager.getNotificationChannel(ExecutionService.CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        val accessibility = PhaseAccessibilityService.instance
        val connected = accessibility != null
        val screenshots = Build.VERSION.SDK_INT >= 34 &&
            ((accessibility?.serviceInfo?.capabilities ?: 0) and
                android.accessibilityservice.AccessibilityServiceInfo.CAPABILITY_CAN_TAKE_SCREENSHOT) != 0
        return ExecutionCapabilities(tasks.capabilities.filter {
            (it in fileActions || it == ExecutionAction.LIST_APPS || connected) &&
                (it != ExecutionAction.CAPTURE_SCREEN || screenshots)
        }, manager.areNotificationsEnabled() && channelEnabled, resumed, connected)
    }

    fun setActivityResumed(value: Boolean) {
        resumed = value
        if (value) clearConfirmation()
        refreshOverlay()
        send { flutter.capabilityChanged(queryCapabilities()) }
    }

    override suspend fun startRun(session: ExecutionSession): HostReply {
        val runId = session.runId
        val existing = this.session
        if (runId.isBlank() || (tasks.runId != null && tasks.runId != runId) ||
            (existing != null && (existing.fileUris != session.fileUris || existing.appPolicy != session.appPolicy))) return HostReply(ChannelError.INVALID_ARGUMENTS)
        if (existing == null) { this.session = session; tasks.begin(runId); activeTargetPackage = null }
        currentAppPolicy = session.currentAppPolicy
        if (!session.deviceTask || deviceActive) return HostReply()
        if (!resumed) return HostReply(ChannelError.UNAVAILABLE)
        if (!queryCapabilities().notificationsAllowed || PhaseAccessibilityService.instance == null) return HostReply(ChannelError.PERMISSION_REQUIRED)
        val ready = CompletableDeferred<HostReply>()
        starting = ready
        return try {
            val intent = Intent(context, ExecutionService::class.java).putExtra(ExecutionService.RUN_ID, runId)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            val reply = withTimeout(5000) { ready.await() }
            if (reply.error != null) { endRun(runId); return reply }
            deviceActive = true
            refreshOverlay()
            reply
        } catch (_: Exception) {
            endRun(runId)
            HostReply(ChannelError.UNAVAILABLE)
        } finally {
            launching = false
            if (starting === ready) starting = null
        }
    }

    fun expectsStart(runId: String): Boolean = tasks.runId == runId && starting != null

    fun serviceStarted(host: ExecutionService, runId: String): Boolean {
        if (!expectsStart(runId)) return false
        service = host
        starting?.complete(HostReply())
        return true
    }

    fun serviceFailed(runId: String) {
        if (tasks.runId == runId) starting?.complete(HostReply(ChannelError.UNAVAILABLE))
    }

    override fun endRun(runId: String) {
        if (tasks.runId != runId) return
        clearConfirmation()
        tasks.end(runId)
        session = null; deviceActive = false; activeTargetPackage = null
        PhaseAccessibilityService.instance?.driver?.clear()
        PhaseAccessibilityService.instance?.visual?.clear()
        PhaseAccessibilityService.instance?.overlay?.hide()
        starting?.complete(HostReply(ChannelError.CANCELLED))
        val host = service
        service = null
        host?.finishTask()
    }

    /** Latch native stop before notifying Dart, so a late dispatch cannot escape cancellation. */
    fun stopFromSystem(runId: String, reason: String? = null) {
        if (tasks.runId != runId) return
        tasks.stop(runId)
        deviceActive = false
        clearConfirmation()
        PhaseAccessibilityService.instance?.overlay?.hide()
        send { flutter.stopRequested(runId, reason) }
        val host = service
        service = null
        host?.finishTask()
    }

    fun serviceDestroyed(host: ExecutionService, runId: String?) {
        if (service !== host || runId == null) return
        service = null
        stopFromSystem(runId, "serviceStopped")
    }

    override fun setConfirmation(confirmation: ExecutionConfirmation?) {
        clearConfirmation()
        if (confirmation == null || resumed || confirmation.runId != tasks.runId ||
            confirmation.expiresAtMs <= System.currentTimeMillis()) return
        this.confirmation = confirmation
        confirmationExpiry = scope.launch {
            delay(confirmation.expiresAtMs - System.currentTimeMillis())
            clearConfirmation()
        }
        refreshOverlay()
    }

    /** Future native panel passes only the decision; never executes an action itself. */
    fun decide(runId: String, toolCallId: String, decision: ConfirmationDecision) {
        val pending = confirmation ?: return
        if (resumed || pending.runId != runId || pending.toolCallId != toolCallId ||
            pending.expiresAtMs <= System.currentTimeMillis()) return
        clearConfirmation()
        if (decision == ConfirmationDecision.STOP) stopFromSystem(runId)
        else send { flutter.confirmationDecision(runId, toolCallId, decision) }
    }

    private fun clearConfirmation() {
        confirmationExpiry?.cancel()
        confirmationExpiry = null
        confirmation = null
        refreshOverlay()
    }

    private suspend fun executeUi(request: ExecutionRequest, progress: suspend (ProgressKind, String) -> Unit): ExecutionResult = deviceQueue.withLock {
        val accessibility = PhaseAccessibilityService.instance
        if (request.action == ExecutionAction.CAPTURE_SCREEN && (!deviceActive || accessibility == null))
            return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.PERMISSION_REQUIRED)
        val target = try { resolveUiTarget(request) { accessibility?.driver?.activePackage() } }
        catch (_: IllegalArgumentException) {
            return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.INVALID_ARGUMENTS)
        } ?: return@withLock ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
            mapOf("reason" to "当前没有可截图的前台应用窗口"), emptyList(), ChannelError.UNAVAILABLE)
        val application = applications.get(target)
        if (application == null || application.packageName != target || !allowed(application)) return@withLock denied(request)
        if (!deviceActive || accessibility == null) return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.PERMISSION_REQUIRED)
        overlaySuppressed = true
        accessibility.overlay.hide()
        try {
            if (request.action == ExecutionAction.OPEN_APP) {
                val intent = applications.launchIntent(target) ?: return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.UNAVAILABLE)
                if (intent.component?.packageName != target) return@withLock denied(request)
                // A settings change while the package lookup was suspended must still veto dispatch.
                if (!allowed(application)) return@withLock denied(request)
                launching = true
                activeTargetPackage = target
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                if (!accessibility.driver.awaitTarget(target)) return@withLock ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                    mapOf("packageName" to target, "actionAccepted" to true, "observationChanged" to false), emptyList(), ChannelError.TIMEOUT)
                if (!allowed(application)) return@withLock denied(request)
                ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, mapOf("packageName" to target, "actionAccepted" to true,
                    "observationChanged" to true, "snapshot" to accessibility.driver.snapshot(target)), emptyList())
            } else if (request.action in visualActions) {
                activeTargetPackage = target
                accessibility.visual.execute(request, target, validatePolicy = {
                    currentCoroutineContext().ensureActive()
                    val current = applications.get(target)
                    if (current == null || !allowed(current)) throw app.xiangyue.phase.vision.VisualBlocked("applicationDenied")
                }, checkpoint = { tasks.checkpoint(request.toolCallId, it) }, progress = progress)
            } else {
                // No implicit launch or switch: snapshot/package/window identity is checked by the driver.
                val result = accessibility.driver.execute(request, target)
                if (result.status == ExecutionStatus.SUCCEEDED) activeTargetPackage = target
                result
            }
        } finally { launching = false; overlaySuppressed = false; refreshOverlay() }
    }

    private fun allowed(app: InstalledApplication): Boolean {
        val frozen = session?.appPolicy ?: return false
        return ApplicationAccess.allows(frozen, currentAppPolicy ?: frozen, app.packageName, app.isSystem)
    }

    private suspend fun listApplications(request: ExecutionRequest): ExecutionResult {
        val all = try { applications.list() }
        catch (error: CancellationException) { throw error }
        catch (_: ApplicationListPermissionRequired) {
            return ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                mapOf("reason" to "未授权获取应用列表，请在相月应用权限设置中允许后重试"), emptyList(), ChannelError.PERMISSION_REQUIRED)
        } catch (_: ApplicationCatalogRestricted) {
            return ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                mapOf("reason" to "系统仅返回相月或基础系统包，应用列表访问受限，请检查应用列表权限"), emptyList(), ChannelError.PERMISSION_REQUIRED)
        } catch (_: Exception) {
            return ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                mapOf("reason" to "应用列表暂不可读取，请检查系统的应用列表访问权限或稍后重试"), emptyList(), ChannelError.UNAVAILABLE)
        }
        val query = (request.arguments["query"] as? String ?: "").lowercase(java.util.Locale.ROOT)
        val offset = (request.arguments["offset"] as? Number)?.toLong() ?: 0L
        val limit = (request.arguments["limit"] as? Number)?.toInt() ?: 30
        val sort = request.arguments["sort"] as? String ?: "name"
        if (offset !in 0..Int.MAX_VALUE.toLong() || limit !in 1..50 || sort !in setOf("name", "installedAt", "size")) return NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.INVALID_ARGUMENTS)
        val filtered = ApplicationCatalog.sorted(all.filter { allowed(it) && "${it.label} ${it.packageName}".lowercase(java.util.Locale.ROOT).contains(query) }, sort)
        val page = mutableListOf<Map<String, Any?>>()
        var bytes = 0
        for (app in filtered.drop(offset.toInt()).take(limit)) {
            val entry = ApplicationCatalog.details(app)
            val size = org.json.JSONObject(entry).toString().toByteArray(Charsets.UTF_8).size
            if (page.isNotEmpty() && bytes + size > 48 * 1024) break
            page.add(entry); bytes += size
        }
        return ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED,
            mapOf("applications" to page, "total" to filtered.size,
                "nextOffset" to if (offset + page.size < filtered.size) offset + page.size else null), emptyList())
    }

    private fun updateApplicationPolicy(policy: ApplicationPolicy) {
        currentAppPolicy = policy
        val runId = tasks.runId ?: return
        val targets = listOfNotNull(activeTargetPackage, confirmation?.arguments?.get("packageName") as? String).distinct()
        scope.launch {
            for (target in targets) {
                val app = try { applications.get(target) } catch (_: Exception) { null }
                if (tasks.runId != runId) return@launch
                if ((target == activeTargetPackage || target == confirmation?.arguments?.get("packageName")) && (app == null || !allowed(app))) {
                    stopFromSystem(runId, "applicationDenied"); return@launch
                }
            }
        }
    }

    private fun denied(request: ExecutionRequest) = ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
        mapOf("reason" to "应用不存在或被当前名单禁止", "reasonCode" to "applicationDenied"), emptyList(), ChannelError.PERMISSION_REQUIRED)

    fun refreshOverlay() {
        val service = PhaseAccessibilityService.instance ?: return
        val id = tasks.runId
        if (id == null || resumed || !deviceActive || overlaySuppressed || launching) { service.overlay.hide(); return }
        val pending = confirmation
        try { service.overlay.show(id, pending, { decision ->
            if (pending != null) decide(id, pending.toolCallId, decision)
        }, { stopFromSystem(id) }) } catch (_: Exception) { stopFromSystem(id, "serviceStopped") }
    }

    fun accessibilityChanged() { send { flutter.capabilityChanged(queryCapabilities()) } }
    fun interruptDevice(reason: String) { if (deviceActive) tasks.runId?.let { stopFromSystem(it, reason) } }
    fun windowChanged(packageName: String?) {
        if (deviceActive && activeTargetPackage != null && !launching && !resumed && packageName != null && packageName != context.packageName && packageName != activeTargetPackage) interruptDevice("targetChanged")
    }

    private fun send(block: suspend () -> Unit) {
        scope.launch {
            try { withTimeout(2000) { block() } } catch (_: Exception) {
                // No replay on reconnect. Missing business results are recovered from Drift.
            }
        }
    }
}
