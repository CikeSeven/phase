package app.xiangyue.phase.execution

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*

class ExecutionCoordinator(private val context: Context, private val flutter: ExecutionFlutterApi) : ExecutionHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val tasks = NativeExecutionTasks(scope, emptyMap()) { progress ->
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
        return ExecutionCapabilities(tasks.capabilities, manager.areNotificationsEnabled() && channelEnabled, resumed)
    }

    fun setActivityResumed(value: Boolean) {
        resumed = value
        if (value) clearConfirmation()
        send { flutter.capabilityChanged(queryCapabilities()) }
    }

    override suspend fun startRun(runId: String): HostReply {
        if (runId.isBlank() || tasks.runId != null) return HostReply(ChannelError.INVALID_ARGUMENTS)
        if (!resumed) return HostReply(ChannelError.UNAVAILABLE)
        if (!queryCapabilities().notificationsAllowed) return HostReply(ChannelError.PERMISSION_REQUIRED)
        tasks.begin(runId)
        val ready = CompletableDeferred<HostReply>()
        starting = ready
        return try {
            val intent = Intent(context, ExecutionService::class.java).putExtra(ExecutionService.RUN_ID, runId)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            val reply = withTimeout(5000) { ready.await() }
            if (reply.error != null) endRun(runId)
            reply
        } catch (_: Exception) {
            endRun(runId)
            HostReply(ChannelError.UNAVAILABLE)
        } finally {
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
        starting?.complete(HostReply(ChannelError.CANCELLED))
        val host = service
        service = null
        host?.finishTask()
    }

    /** Latch native stop before notifying Dart, so a late dispatch cannot escape cancellation. */
    fun stopFromSystem(runId: String) {
        if (tasks.runId != runId) return
        tasks.stop(runId)
        clearConfirmation()
        send { flutter.stopRequested(runId) }
        val host = service
        service = null
        host?.finishTask()
    }

    fun serviceDestroyed(host: ExecutionService, runId: String?) {
        if (service !== host || runId == null) return
        service = null
        stopFromSystem(runId)
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
        // S4.5 adds Accessibility overlay; no unimplemented action is advertised today.
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
    }

    private fun send(block: suspend () -> Unit) {
        scope.launch {
            try { withTimeout(2000) { block() } } catch (_: Exception) {
                // No replay on reconnect. Missing business results are recovered from Drift.
            }
        }
    }
}
