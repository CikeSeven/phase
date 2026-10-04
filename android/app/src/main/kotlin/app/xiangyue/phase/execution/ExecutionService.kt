package app.xiangyue.phase.execution

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import app.xiangyue.phase.MainActivity
import app.xiangyue.phase.PhaseApplication
import app.xiangyue.phase.R

/** User-visible device, installation and process tasks share one engine and service. */
class ExecutionService : Service() {
    private lateinit var runtime: ExecutionRuntime
    private val runOwners = linkedMapOf<String, Boolean>()
    private val processOwners = linkedMapOf<String, String>()
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        runtime = (application as PhaseApplication).runtime
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "任务执行", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ALL) {
            runOwners.keys.toList().forEach { runtime.coordinator.stopFromSystem(it) }
            processOwners.keys.toList().forEach { runtime.processes.stopFromSystem(it) }
            refreshOrStop()
            return START_NOT_STICKY
        }
        val processOwner = intent?.getStringExtra(PROCESS_OWNER)
        if (processOwner != null) {
            if (intent.action == ACTION_STOP) {
                runtime.processes.stopFromSystem(processOwner)
                if (runOwners.containsKey(processOwner)) {
                    runtime.coordinator.stopFromSystem(processOwner)
                }
                return START_NOT_STICKY
            }
            if (!runtime.processes.expectsStart(processOwner)) {
                if (runOwners.isEmpty() && processOwners.isEmpty()) stopSelf(startId)
                return START_NOT_STICKY
            }
            processOwners[processOwner] = intent.getStringExtra(TASK_LABEL) ?: "Linux 任务"
            try {
                updateForeground()
                runtime.processes.serviceStarted(this, processOwner)
            } catch (_: Exception) {
                runtime.processes.serviceFailed(processOwner)
                finishProcess(processOwner)
            }
            return START_NOT_STICKY
        }
        val id = intent?.getStringExtra(RUN_ID)
        if (id == null) { stopSelf(startId); return START_NOT_STICKY }
        if (intent.action == ACTION_STOP) {
            runtime.coordinator.stopFromSystem(id)
            if (processOwners.containsKey(id)) runtime.processes.stopFromSystem(id)
            if (runOwners.isEmpty() && processOwners.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!runtime.coordinator.expectsStart(id)) {
            // An old start intent must not stop or relabel a newer task's service.
            if (runOwners.isEmpty() && processOwners.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        runOwners[id] = intent.getBooleanExtra(DEVICE_TASK, false)
        try {
            updateForeground()
            if (!runtime.coordinator.serviceStarted(this, id)) finishTask(id)
        } catch (_: Exception) {
            runtime.coordinator.serviceFailed(id)
            finishTask(id)
        }
        return START_NOT_STICKY
    }

    private fun notification(id: String?): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val count = runOwners.size + processOwners.size
        val stopIntent = Intent(this, ExecutionService::class.java)
            .setAction(ACTION_STOP_ALL)
            .setData(Uri.Builder().scheme("phase-task").authority("stop-all").build())
        val stop = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        builder.addAction(Notification.Action.Builder(null, "停止所有任务", stop).build())
        return builder.setSmallIcon(R.drawable.ic_execution_notification)
            .setContentTitle("相月任务执行中")
            .setContentText(if (count > 1) "${count} 个会话任务正在运行" else "点按返回相月，可随时停止任务")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
    }

    fun finishTask(id: String) {
        runOwners.remove(id)
        refreshOrStop()
    }

    fun finishProcess(owner: String) {
        processOwners.remove(owner)
        refreshOrStop()
    }
    private fun refreshOrStop() {
        if (runOwners.isEmpty() && processOwners.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            releaseWakeLock()
            stopSelf()
        } else updateForeground()
    }
    private fun updateForeground() {
        acquireWakeLock()
        val value = notification(runOwners.keys.firstOrNull())
        if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION_ID, value, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTIFICATION_ID, value)
    }
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "phase:chat-runs")
            .apply {
                setReferenceCounted(false)
                acquire()
            }
    }
    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }
    override fun onDestroy() {
        runtime.processes.serviceStopped(this)
        runtime.coordinator.serviceDestroyed(this, runOwners.keys.toSet())
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "phase_execution"
        const val RUN_ID = "runId"
        const val DEVICE_TASK = "deviceTask"
        const val PROCESS_OWNER = "processOwner"
        const val TASK_LABEL = "taskLabel"
        private const val ACTION_STOP = "app.xiangyue.phase.STOP_EXECUTION"
        private const val ACTION_STOP_ALL = "app.xiangyue.phase.STOP_ALL_EXECUTION"
        private const val NOTIFICATION_ID = 4102
    }
}
