package app.xiangyue.phase

import android.app.Dialog
import android.app.Instrumentation
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import java.io.File
import java.util.UUID

/** A temporary opaque native window in Phase: no model requests or conversation/configuration reads. */
class VisualSmokeScenario(private val instrumentation: Instrumentation, private val stage: (String) -> Unit) {
    suspend fun run(report: Bundle) {
        val context = instrumentation.targetContext
        val target = context.packageName
        val app = context.applicationContext as PhaseApplication
        stage("self-activity-launch")
        // Flutter can keep drawing continuously; do not wait for the main queue to become idle.
        val monitor = instrumentation.addMonitor(MainActivity::class.java.name, null, false)
        val activity = try {
            // Instrumentation starts with no foreground Activity. Use the shell launcher for test
            // setup, without UiAutomation's default suppression of real accessibility services.
            val automation = instrumentation.getUiAutomation(android.app.UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
            withContext(Dispatchers.IO) {
                val descriptor = automation.executeShellCommand("am start -n $target/${MainActivity::class.java.name}")
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            instrumentation.waitForMonitorWithTimeout(monitor, 5000) ?: error("Activity did not launch")
        } finally { instrumentation.removeMonitor(monitor) }
        stage("self-activity-resume")
        val coordinator = withContext(Dispatchers.Main) { app.runtime.coordinator }
        withTimeout(5000) { while (!withContext(Dispatchers.Main) { coordinator.queryCapabilities().activityResumed }) delay(20) }
        val run = "visual-smoke-${UUID.randomUUID()}"
        var clicks = 0
        lateinit var dialog: Dialog
        lateinit var button: Button
        lateinit var text: TextView
        withContext(Dispatchers.Main) {
            dialog = Dialog(activity)
            val layout = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.WHITE)
            }
            text = TextView(activity).apply { setTextColor(Color.BLACK); this.text = "相月视觉测试：初始页面" }
            button = Button(activity).apply {
                this.text = "测试按钮"
                setOnClickListener { clicks++; text.text = "相月视觉测试：已点击 $clicks 次" }
            }
            layout.addView(text)
            layout.addView(button, LinearLayout.LayoutParams(500, 200))
            dialog.setContentView(layout)
            dialog.show()
            dialog.window!!.setBackgroundDrawable(ColorDrawable(Color.WHITE))
            dialog.window!!.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        try {
            stage("self-catalog")
            val catalog = ApplicationCatalog(context)
            val own = catalog.get(target)
            report.putBoolean("phase_self_found", own?.packageName == target)
            check(own?.packageName == target)
            stage("self-catalog-list")
            check(catalog.list().any { it.packageName == target })
            stage("self-permissions")
            // Replacing/restarting the target process can precede the system's service rebind.
            withTimeoutOrNull(7000) {
                while (!withContext(Dispatchers.Main) { coordinator.queryCapabilities().accessibilityConnected }) delay(50)
            }
            val caps = withContext(Dispatchers.Main) { coordinator.queryCapabilities() }
            report.putBoolean("phase_notifications", caps.notificationsAllowed)
            report.putBoolean("phase_accessibility", caps.accessibilityConnected)
            val policy = ApplicationPolicy(ApplicationListMode.BLACKLIST, emptyList(), emptyList(), emptyList())
            val reply = withContext(Dispatchers.Main) { coordinator.startRun(ExecutionSession(run, true, emptyList(), policy, policy)) }
            report.putString("phase_host_error", reply.error?.name ?: "none")
            check(reply.error == null)
            withTimeout(5000) { while (!withContext(Dispatchers.Main) { button.isShown && button.width > 0 }) delay(20) }
            val point = withContext(Dispatchers.Main) {
                val location = IntArray(2); button.getLocationOnScreen(location)
                (location[0] + button.width / 2.0) to (location[1] + button.height / 2.0)
            }
            suspend fun call(action: ExecutionAction, arguments: Map<String, Any?>, id: String = UUID.randomUUID().toString()): ExecutionResult {
                val result = withContext(Dispatchers.Main) {
                    coordinator.execute(ExecutionRequest(run, id, action, arguments,
                        if (action == ExecutionAction.CAPTURE_SCREEN) ExecutionTarget() else ExecutionTarget(packageName = target), 10000))
                }
                // Only delete temporary artifacts returned by this test's own call.
                result.artifacts.forEach { it.localPath?.let { path -> check(File(path).isFile); File(path).delete() } }
                report.putString("phase_native_status", "${result.status}/${result.error}")
                if (result.result["reason"] is String) report.putString("phase_reason", result.result["reason"] as String)
                if (result.result["observationError"] is String) report.putString("phase_observation_error", result.result["observationError"] as String)
                return result
            }
            stage("direct-screen-tap-without-screenshot")
            val tap = mapOf("type" to "tap", "x" to point.first, "y" to point.second)
            check(call(ExecutionAction.PERFORM_GESTURES, mapOf("packageName" to target, "actions" to listOf(tap))).status == ExecutionStatus.SUCCEEDED)
            withTimeout(3000) { while (withContext(Dispatchers.Main) { clicks } != 1) delay(20) }
            stage("capture-current-page")
            val captured = call(ExecutionAction.CAPTURE_SCREEN, emptyMap())
            check(captured.status == ExecutionStatus.SUCCEEDED)
            val screenshot = captured.result["screenshot"] as Map<*, *>
            check(screenshot["packageName"] == target)
            val bounds = screenshot["screenBounds"] as List<*>
            val left = (bounds[0] as Number).toDouble(); val top = (bounds[1] as Number).toDouble()
            val width = (bounds[2] as Number).toDouble() - left; val height = (bounds[3] as Number).toDouble() - top
            val imageWidth = (screenshot["imageWidth"] as Number).toInt(); val imageHeight = (screenshot["imageHeight"] as Number).toInt()
            val imageTap = mapOf("type" to "tap", "x" to (point.first - left) * imageWidth / width, "y" to (point.second - top) * imageHeight / height)
            stage("content-change-and-repeated-image-coordinates")
            withContext(Dispatchers.Main) { text.text = "页面内容已经变化，图片宽高仍可用于坐标换算" }
            for (expected in 2..3) {
                val result = call(ExecutionAction.PERFORM_GESTURES, mapOf("packageName" to target,
                    "coordinateSpace" to "image_pixels", "imageWidth" to imageWidth, "imageHeight" to imageHeight,
                    "actions" to listOf(imageTap)))
                check(result.status == ExecutionStatus.SUCCEEDED)
                withTimeout(3000) { while (withContext(Dispatchers.Main) { clicks } != expected) delay(20) }
            }
            stage("whole-batch-bounds-check")
            check(call(ExecutionAction.PERFORM_GESTURES, mapOf("packageName" to target,
                "actions" to listOf(tap, mapOf("type" to "tap", "x" to 100000, "y" to 100000)))).error == ChannelError.INVALID_ARGUMENTS)
            check(withContext(Dispatchers.Main) { clicks } == 3)
            stage("cancel-after-first-action")
            coroutineScope {
                val id = UUID.randomUUID().toString()
                val pending = async { call(ExecutionAction.PERFORM_GESTURES, mapOf("packageName" to target,
                    "actions" to listOf(tap, mapOf("type" to "wait", "durationMs" to 2000), tap)), id) }
                withTimeout(3000) { while (withContext(Dispatchers.Main) { clicks } != 4) delay(20) }
                withContext(Dispatchers.Main) { coordinator.cancel(id) }
                check(pending.await().status == ExecutionStatus.CANCELLED)
                check(withContext(Dispatchers.Main) { clicks } == 4)
            }
            report.putInt("phase_clicks", clicks)
            report.putString("phase_result", "passed: self catalog, direct tap, real screenshot, changed content, reused image coordinates, bounds, cancellation")
        } finally {
            withContext(Dispatchers.Main) { coordinator.endRun(run); dialog.dismiss() }
        }
    }
}
