package app.xiangyue.phase.execution

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import app.xiangyue.phase.MainActivity
import app.xiangyue.phase.PhaseApplication
import app.xiangyue.phase.R

/** User-visible device, installation and process tasks share one engine and service. */
class ExecutionService : Service() {
    private lateinit var runtime: ExecutionRuntime
    private var runId: String? = null
    private val processOwners = linkedMapOf<String, String>()

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
        val processOwner = intent?.getStringExtra(PROCESS_OWNER)
        if (processOwner != null) {
            if (intent.action == ACTION_STOP) {
                runtime.processes.stopFromSystem(processOwner)
                if (runId == processOwner) runtime.coordinator.stopFromSystem(processOwner)
                return START_NOT_STICKY
            }
            if (!runtime.processes.expectsStart(processOwner)) {
                if (runId == null && processOwners.isEmpty()) stopSelf(startId)
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
            if (runId == null && processOwners.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!runtime.coordinator.expectsStart(id)) {
            // An old start intent must not stop or relabel a newer task's service.
            if (runId == null && processOwners.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        runId = id
        try {
            val notification = notification(id)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            if (!runtime.coordinator.serviceStarted(this, id)) finishTask()
        } catch (_: Exception) {
            runtime.coordinator.serviceFailed(id)
            finishTask()
        }
        return START_NOT_STICKY
    }

    private fun notification(id: String?): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val stops = processOwners.toMutableMap()
        if (id != null) stops.putIfAbsent(id, "设备任务")
        for ((owner, label) in stops) {
            val intent = Intent(this, ExecutionService::class.java).setAction(ACTION_STOP)
                .setData(Uri.Builder().scheme("phase-task").authority("stop").appendPath(owner).build())
                .putExtra(if (processOwners.containsKey(owner)) PROCESS_OWNER else RUN_ID, owner)
            val stop = PendingIntent.getService(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(Notification.Action.Builder(null, "停止$label", stop).build())
        }
        return builder.setSmallIcon(R.drawable.ic_execution_notification)
            .setContentTitle("相月任务执行中")
            .setContentText("点按返回相月，可随时停止任务")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
    }

    fun finishTask() {
        runId = null
        refreshOrStop()
    }

    fun finishProcess(owner: String) {
        processOwners.remove(owner)
        refreshOrStop()
    }
    private fun refreshOrStop() {
        if (runId == null && processOwners.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } else updateForeground()
    }
    private fun updateForeground() {
        val value = notification(runId)
        if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION_ID, value, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTIFICATION_ID, value)
    }
    override fun onDestroy() {
        runtime.processes.serviceStopped(this)
        runtime.coordinator.serviceDestroyed(this, runId)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "phase_execution"
        const val RUN_ID = "runId"
        const val PROCESS_OWNER = "processOwner"
        const val TASK_LABEL = "taskLabel"
        private const val ACTION_STOP = "app.xiangyue.phase.STOP_EXECUTION"
        private const val NOTIFICATION_ID = 4102
    }
}
