package app.xiangyue.phase.execution

import android.app.KeyguardManager
import app.xiangyue.phase.MainActivity
import app.xiangyue.phase.accessibility.TaskPanelSession
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import app.xiangyue.phase.files.AppFileDriver
import app.xiangyue.phase.accessibility.PhaseAccessibilityService
import app.xiangyue.phase.accessibility.DeviceActionQueue
import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.applications.ApplicationCatalogRestricted
import app.xiangyue.phase.applications.ApplicationListPermissionRequired
import app.xiangyue.phase.shizuku.ShizukuDeviceHost

class ExecutionCoordinator(private val context: Context, private val flutter: ExecutionFlutterApi) : ExecutionHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val shizuku = ShizukuDeviceHost(context, ::stopFromSystem)
    val files = AppFileDriver(context)
    private val applications = ApplicationCatalog(context)
    val setup = ExecutionSetup(context, files, applications)
    private val sessions = mutableMapOf<String, ExecutionSession>()
    private val startGate = Mutex()
    private val deviceQueue = DeviceActionQueue()
    private var deviceActive = false
    private var deviceRunId: String? = null
    private var virtualDeviceActive = false
    private var launching = false
    private var overlaySuppressed = false
    private val panel = TaskPanelSession()
    private data class PanelSubmission(val sourceRunId: String, var nextRunId: String? = null, var cancelled: Boolean = false)
    private var panelSubmission: PanelSubmission? = null
    private val fileActions = setOf(ExecutionAction.READ_FILE, ExecutionAction.WRITE_FILE, ExecutionAction.LIST_FILES)
    private val visualActions = setOf(ExecutionAction.CAPTURE_SCREEN, ExecutionAction.PERFORM_GESTURES)
    private val tasks: NativeExecutionTasks = NativeExecutionTasks(scope, ExecutionAction.entries.associateWith { action ->
        NativeAction { request, progress ->
            if (action in fileActions) files.execute(request, sessions[request.runId]?.fileUris ?: emptyList())
            else if (action == ExecutionAction.LIST_APPS) listApplications(request)
            else if (action == ExecutionAction.CONTROL_DISPLAY) deviceQueue.withLock {
                if (request.runId != deviceRunId) {
                    return@withLock NativeExecutionTasks.result(
                        request.toolCallId,
                        ExecutionStatus.FAILED,
                        ChannelError.PERMISSION_REQUIRED,
                    )
                }
                virtualDeviceActive = true
                shizuku.execute(request, applicationExists = { target ->
                    applications.get(target) != null
                }, checkpoint = { tasks.checkpoint(request.runId, request.toolCallId, it) })
            }
            else executeUi(request, progress)
        }
    }) { progress ->
        send { flutter.progress(progress) }
    }
    private var resumed = false
    private var service: ExecutionService? = null
    private val starting = mutableMapOf<String, CompletableDeferred<HostReply>>()
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
            (if (it == ExecutionAction.CONTROL_DISPLAY) shizuku.available() else it in fileActions || it == ExecutionAction.LIST_APPS || connected) &&
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
        return startGate.withLock { startRunLocked(session) }
    }

    private suspend fun startRunLocked(session: ExecutionSession): HostReply {
        val runId = session.runId
        val existing = sessions[runId]
        val deviceRequested = existing?.deviceTask == true || session.deviceTask
        if (runId.isBlank() ||
            (existing != null && existing.fileUris != session.fileUris)) return HostReply(ChannelError.INVALID_ARGUMENTS)
        if (deviceRequested && deviceRunId != null && deviceRunId != runId) {
            return HostReply(ChannelError.UNAVAILABLE)
        }
        val fromPanel = panelSubmission?.takeIf {
            !it.cancelled && it.nextRunId == null && it.sourceRunId == panel.runId && panel.finished
        }
        if (deviceRequested && !deviceActive && deviceRunId == null) {
            if (!resumed && fromPanel == null) return HostReply(ChannelError.UNAVAILABLE)
            if (context.getSystemService(KeyguardManager::class.java).isKeyguardLocked ||
                !queryCapabilities().notificationsAllowed || PhaseAccessibilityService.instance == null)
                return HostReply(ChannelError.PERMISSION_REQUIRED)
        }
        if (fromPanel != null) fromPanel.nextRunId = runId
        if (existing == null) {
            tasks.begin(runId)
            if (deviceRequested && fromPanel == null && deviceRunId == null) panel.clear()
        }
        val registeredSession = ExecutionSession(
            runId,
            deviceRequested,
            session.fileUris,
        )
        sessions[runId] = registeredSession
        if (deviceActive && deviceRunId == runId) return HostReply()
        val ready = CompletableDeferred<HostReply>()
        starting[runId] = ready
        return try {
            val intent = Intent(context, ExecutionService::class.java)
                .putExtra(ExecutionService.RUN_ID, runId)
                .putExtra(ExecutionService.DEVICE_TASK, registeredSession.deviceTask)
            if (service == null && Build.VERSION.SDK_INT >= 26) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            val reply = withTimeout(5000) { ready.await() }
            if (reply.error != null) { endRun(runId); return reply }
            if (fromPanel?.cancelled == true || !tasks.contains(runId)) {
                endRun(runId); return HostReply(ChannelError.CANCELLED)
            }
            if (registeredSession.deviceTask) {
                deviceActive = true
                deviceRunId = runId
                panel.begin(runId)
                refreshOverlay()
            }
            reply
        } catch (_: Exception) {
            endRun(runId)
            HostReply(ChannelError.UNAVAILABLE)
        } finally {
            launching = false
            if (starting[runId] === ready) starting.remove(runId)
        }
    }

    fun expectsStart(runId: String): Boolean = tasks.contains(runId) && starting.containsKey(runId)

    fun serviceStarted(host: ExecutionService, runId: String): Boolean {
        if (!expectsStart(runId)) return false
        service = host
        starting[runId]?.complete(HostReply())
        return true
    }

    fun serviceFailed(runId: String) {
        starting[runId]?.complete(HostReply(ChannelError.UNAVAILABLE))
    }

    override fun endRun(runId: String) {
        if (!tasks.contains(runId)) return
        if (deviceRunId == runId) {
            panel.finish(runId)
            deviceActive = false
            deviceRunId = null
            virtualDeviceActive = false
            PhaseAccessibilityService.instance?.driver?.clear()
            PhaseAccessibilityService.instance?.visual?.clear()
        }
        if (confirmation?.runId == runId) clearConfirmation()
        shizuku.endOwner(runId)
        tasks.end(runId)
        sessions.remove(runId)
        refreshOverlay()
        starting.remove(runId)?.complete(HostReply(ChannelError.CANCELLED))
        service?.finishTask(runId)
    }

    fun externalOwnerStopped(owner: String) { scope.launch { stopFromSystem(owner, "serviceStopped") } }

    /** Latch native stop before notifying Dart, so a late dispatch cannot escape cancellation. */
    fun stopFromSystem(runId: String, reason: String? = null) {
        val submission = panelSubmission
        if (reason != "panelMessage" && submission != null &&
            runId in setOf(submission.sourceRunId, submission.nextRunId)) cancelPanelSubmission()
        if (!tasks.contains(runId)) return
        shizuku.endOwner(runId)
        tasks.stop(runId)
        if (deviceRunId == runId) {
            deviceActive = false
            deviceRunId = null
            panel.finish(runId)
        }
        if (confirmation?.runId == runId) clearConfirmation()
        refreshOverlay()
        send { flutter.stopRequested(runId, reason) }
        service?.finishTask(runId)
    }

    fun serviceDestroyed(host: ExecutionService, runIds: Set<String>) {
        if (service !== host) return
        service = null
        runIds.forEach { stopFromSystem(it, "serviceStopped") }
    }

    override fun setConfirmation(confirmation: ExecutionConfirmation?) {
        clearConfirmation()
        if (confirmation == null || resumed || !tasks.contains(confirmation.runId) ||
            confirmation.expiresAtMs <= System.currentTimeMillis()) return
        this.confirmation = confirmation
        confirmationExpiry = scope.launch {
            delay(confirmation.expiresAtMs - System.currentTimeMillis())
            clearConfirmation()
        }
        refreshOverlay()
    }

    /** Native panel passes only the decision; never executes an action itself. */
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
        virtualDeviceActive = false
        val accessibility = PhaseAccessibilityService.instance
        accessibility?.overlay?.awaitInputIdle()
        currentCoroutineContext().ensureActive()
        if (request.action == ExecutionAction.CAPTURE_SCREEN &&
            (!deviceActive || request.runId != deviceRunId || accessibility == null))
            return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.PERMISSION_REQUIRED)
        val target = try { resolveUiTarget(request) { accessibility?.driver?.activePackage() } }
        catch (_: IllegalArgumentException) {
            return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.INVALID_ARGUMENTS)
        } ?: return@withLock ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
            mapOf("reason" to "当前没有可截图的前台应用窗口"), emptyList(), ChannelError.UNAVAILABLE)
        val application = applications.get(target)
        if (application == null || application.packageName != target) return@withLock applicationUnavailable(request)
        if (!deviceActive || request.runId != deviceRunId || accessibility == null)
            return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.PERMISSION_REQUIRED)
        windowChanged(accessibility.driver.activePackage())
        overlaySuppressed = true
        accessibility.overlay.hide()
        try {
            if (request.action == ExecutionAction.OPEN_APP) {
                val intent = applications.launchIntent(target) ?: return@withLock NativeExecutionTasks.result(request.toolCallId, ExecutionStatus.FAILED, ChannelError.UNAVAILABLE)
                if (intent.component?.packageName != target) return@withLock ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                    mapOf("reason" to "应用启动目标与指定包名不一致", "reasonCode" to "targetChanged"), emptyList(), ChannelError.TARGET_CHANGED)
                launching = true
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                if (!accessibility.driver.awaitTarget(target)) return@withLock ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                    mapOf("packageName" to target, "actionAccepted" to true, "observationChanged" to false), emptyList(), ChannelError.TIMEOUT)
                ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, mapOf("packageName" to target, "actionAccepted" to true,
                    "observationChanged" to true, "snapshot" to accessibility.driver.snapshot(target)), emptyList())
            } else if (request.action in visualActions) {
                accessibility.visual.execute(request, target, validateTarget = { packageName ->
                    currentCoroutineContext().ensureActive()
                    val current = applications.get(packageName)
                    if (current == null) throw app.xiangyue.phase.vision.VisualBlocked("applicationUnavailable")
                }, checkpoint = { tasks.checkpoint(request.runId, request.toolCallId, it) }, progress = progress)
            } else {
                // No implicit launch or switch: snapshot/package/window identity is checked by the driver.
                accessibility.driver.execute(request, target)
            }
        } finally { launching = false; overlaySuppressed = false; refreshOverlay() }
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
        val filtered = ApplicationCatalog.sorted(all.filter { "${it.label} ${it.packageName}".lowercase(java.util.Locale.ROOT).contains(query) }, sort)
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

    private fun applicationUnavailable(request: ExecutionRequest) = ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
        mapOf("reason" to "目标应用不存在或已不可用", "reasonCode" to "applicationUnavailable"), emptyList(), ChannelError.UNAVAILABLE)

    override fun setTaskPanel(snapshot: TaskPanelSnapshot) {
        if (snapshot.runId != deviceRunId || !deviceActive) return
        val wasWaiting = panel.waitingForUser
        panel.update(snapshot)
        if (wasWaiting && !panel.waitingForUser) clearHandoffTarget()
        refreshOverlay()
    }

    private fun clearHandoffTarget() {
        PhaseAccessibilityService.instance?.driver?.clear()
        PhaseAccessibilityService.instance?.visual?.clear()
    }

    private fun continueFromPanel(runId: String, toolCallId: String) {
        if (resumed || !deviceActive || !panel.takeContinue(runId, toolCallId)) return
        clearHandoffTarget()
        refreshOverlay()
        scope.launch {
            try { withTimeout(2000) { flutter.continueRequested(runId, toolCallId) } }
            catch (_: Exception) { stopFromSystem(runId, "serviceStopped") }
        }
    }

    private fun submitFromPanel(runId: String, text: String) {
        val accessibility = PhaseAccessibilityService.instance ?: return
        if (resumed || panel.runId != runId || panelSubmission != null ||
            context.getSystemService(KeyguardManager::class.java).isKeyguardLocked ||
            text.isBlank() || text.length > 16000) {
            accessibility.overlay.inputFinished(text, "当前无法发送，请返回相月重试")
            return
        }
        val submission = PanelSubmission(runId)
        panelSubmission = submission
        if (tasks.contains(runId)) stopFromSystem(runId, "panelMessage")
        refreshOverlay()
        scope.launch {
            val error = try {
                withTimeout(60000) { flutter.messageRequested(runId, text) }
            } catch (_: TimeoutCancellationException) {
                cancelPanelSubmission()
                "发送超时，请返回相月查看"
            } catch (_: Exception) {
                cancelPanelSubmission()
                "任务通道暂不可用，请返回相月重试"
            }
            if (panelSubmission !== submission) return@launch
            panelSubmission = null
            // An accepted message remains accepted even if its new run was immediately stopped.
            accessibility.overlay.inputFinished(text, error)
            refreshOverlay()
        }
    }

    private fun cancelPanelSubmission() {
        val submission = panelSubmission ?: return
        if (submission.cancelled) return
        submission.cancelled = true
        send { flutter.stopRequested(submission.sourceRunId, "panelMessageCancelled") }
        submission.nextRunId?.let { if (tasks.contains(it)) stopFromSystem(it) }
    }

    private fun stopFromPanel(runId: String) {
        cancelPanelSubmission()
        stopFromSystem(runId)
        refreshOverlay()
    }

    fun refreshOverlay() {
        val service = PhaseAccessibilityService.instance ?: return
        val id = panel.runId
        val locked = context.getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if (id == null || resumed || locked || (!deviceActive && !panel.finished) || overlaySuppressed || launching) {
            service.overlay.hide(); return
        }
        val pending = confirmation
        try {
            service.overlay.show(
                id, panel.snapshot, pending, panel.finished, panel.continuing, panelSubmission != null,
                decide = { decision -> if (pending != null) decide(id, pending.toolCallId, decision) },
                stop = { stopFromPanel(id) },
                resume = { callId -> continueFromPanel(id, callId) },
                send = { text -> submitFromPanel(id, text) },
                open = {
                    if (panel.runId == id) {
                        if (panel.finished && panelSubmission == null && panel.dismiss(id)) service.overlay.dismiss()
                        else service.overlay.hide()
                        context.startActivity(Intent(context, MainActivity::class.java).addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP))
                    }
                },
                close = { if (panelSubmission == null && panel.dismiss(id)) service.overlay.dismiss() },
            )
        } catch (_: Exception) {
            service.overlay.hide()
            if (deviceActive) stopFromSystem(id, "serviceStopped") else panel.clear()
        }
    }

    fun accessibilityChanged() { send { flutter.capabilityChanged(queryCapabilities()) } }
    fun interruptDevice(reason: String) {
        cancelPanelSubmission()
        if (deviceActive && !virtualDeviceActive) deviceRunId?.let { stopFromSystem(it, reason) }
        refreshOverlay()
    }
    fun windowChanged(packageName: String?) {
        // Navigation invalidates old node identities, not the logical agent run.
        PhaseAccessibilityService.instance?.driver?.invalidateForeground(packageName)
        if (panel.finished) refreshOverlay()
    }

    private fun send(block: suspend () -> Unit) {
        scope.launch {
            try { withTimeout(2000) { block() } } catch (_: Exception) {
                // No replay on reconnect. Missing business results are recovered from Drift.
            }
        }
    }
}
