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

/** Only a user-started device task holds this service; process death never restarts the Loop. */
class ExecutionService : Service() {
    private lateinit var runtime: ExecutionRuntime
    private var runId: String? = null

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
        val id = intent?.getStringExtra(RUN_ID)
        if (id == null) { stopSelf(startId); return START_NOT_STICKY }
        if (intent.action == ACTION_STOP) {
            runtime.coordinator.stopFromSystem(id)
            if (runId == null) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!runtime.coordinator.expectsStart(id)) {
            // An old start intent must not stop or relabel a newer task's service.
            if (runId == null) stopSelf(startId)
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

    private fun notification(id: String): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 0,
            Intent(this, ExecutionService::class.java).setAction(ACTION_STOP)
                .setData(Uri.Builder().scheme("phase-task").authority("stop").appendPath(id).build())
                .putExtra(RUN_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.ic_execution_notification)
            .setContentTitle("相月任务执行中")
            .setContentText("点按返回相月，可随时停止任务")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, "停止任务", stop).build())
            .build()
    }

    fun finishTask() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        runtime.coordinator.serviceDestroyed(this, runId)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "phase_execution"
        const val RUN_ID = "runId"
        private const val ACTION_STOP = "app.xiangyue.phase.STOP_EXECUTION"
        private const val NOTIFICATION_ID = 4102
    }
}
