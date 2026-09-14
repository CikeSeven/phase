package app.xiangyue.phase.vision

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.view.WindowManager
import android.view.accessibility.AccessibilityWindowInfo
import app.xiangyue.phase.accessibility.PhaseAccessibilityService
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.roundToInt

/** Only the approved application window is captured; overlays and other applications are excluded. */
class VisualDriver(private val service: PhaseAccessibilityService) {
    private var deliveredFile: File? = null
    fun clear() { deliveredFile?.delete(); deliveredFile = null }
    private fun rotation() = service.getSystemService(WindowManager::class.java).defaultDisplay.rotation
    private fun window(target: String): Pair<Int, Rect> {
        // Reuse the same lock-screen/manual-intervention guards as node actions.
        service.driver.snapshot(target)
        val windows = service.windows
        try {
            val window = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isActive }
                ?: throw VisualBlocked("targetChanged")
            val root = window.root ?: throw VisualBlocked("targetChanged")
            try { if (root.packageName?.toString() != target) throw VisualBlocked("targetChanged") }
            finally { root.recycle() }
            return window.id to Rect().also(window::getBoundsInScreen)
        } finally { windows.forEach { it.recycle() } }
    }

    suspend fun execute(
        request: ExecutionRequest,
        target: String,
        validatePolicy: suspend () -> Unit,
        checkpoint: (Map<String, Any?>) -> Unit,
        progress: suspend (ProgressKind, String) -> Unit,
    ): ExecutionResult {
        var batch: GestureBatch? = null
        return try {
            if (request.action == ExecutionAction.PERFORM_GESTURES) {
                val coordinates = GestureCoordinates.parse(request.arguments)
                val parsed = GesturePlan.parse(request.arguments["actions"])
                validatePolicy()
                val (_, initialBounds) = window(target)
                // Resolve the whole batch once, before any dispatch. The coordinate convention
                // can be reused; it is not tied to a screenshot's lifetime or content events.
                val steps = coordinates.toScreen(parsed, gestureBounds(initialBounds))
                batch = GestureBatch(checkpoint)
                var stepIndex = 0
                val accepted = batch.execute(steps, validate = {
                    progress(ProgressKind.STAGE, "正在执行第 ${stepIndex + 1}/${steps.size} 步手势")
                    validatePolicy()
                    val (_, bounds) = window(target)
                    gestureBounds(bounds).check(steps[stepIndex])
                    stepIndex++
                }, dispatch = { step ->
                    if (step.type == "wait") { delay(step.durationMs); true } else gesture(step)
                })
                if (!accepted) return ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                    batch.state() + ("reason" to "gestureRejected"), emptyList(), ChannelError.EXECUTION_FAILED)
            }
            try {
                validatePolicy()
                val (frame, artifact) = capture(target, validatePolicy)
                ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED,
                    (batch?.state() ?: emptyMap()) + ("screenshot" to frame.metadata()), listOf(artifact))
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                // Observation cannot retroactively fail or replay a completed gesture batch.
                if (batch == null) throw error
                ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED,
                    batch.state() + ("observationError" to reason(error)), emptyList())
            }
        } catch (error: CancellationException) {
            throw error // NativeExecutionTasks preserves the latest immutable checkpoint.
        } catch (error: Exception) {
            val reason = reason(error)
            ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                (batch?.state() ?: emptyMap()) + ("reason" to reason), emptyList(),
                when (reason) {
                    "targetChanged" -> ChannelError.TARGET_CHANGED
                    "invalidArguments" -> ChannelError.INVALID_ARGUMENTS
                    else -> ChannelError.EXECUTION_FAILED
                })
        }
    }

    private fun gestureBounds(bounds: Rect) = GestureBounds(bounds.left, bounds.top, bounds.right, bounds.bottom)

    private fun reason(error: Exception): String = when (error) {
        is VisualBlocked -> error.reason
        is app.xiangyue.phase.accessibility.UiBlocked -> error.reason
        is IllegalArgumentException -> "invalidArguments"
        else -> "screenshotFailed"
    }

    private suspend fun capture(target: String, validatePolicy: suspend () -> Unit): Pair<VisualFrame, ExecutionArtifact> {
        deliveredFile?.delete(); deliveredFile = null
        if (Build.VERSION.SDK_INT < 34) throw VisualBlocked("requiresAndroid14")
        if (service.serviceInfo.capabilities and android.accessibilityservice.AccessibilityServiceInfo.CAPABILITY_CAN_TAKE_SCREENSHOT == 0)
            throw VisualBlocked("screenshotPermissionRequired")
        val (id, bounds) = window(target)
        val rotation = rotation()
        val bitmap = screenshot(id)
        val file = File(service.cacheDir, "visual-${UUID.randomUUID()}.png")
        var delivered = false
        try {
            validatePolicy()
            val (afterId, afterBounds) = window(target)
            if (id != afterId || bounds != afterBounds || rotation != rotation()) throw VisualBlocked("targetChanged")
            // Never guess the origin/scale for cropped or vendor-specific screenshot buffers.
            if (bitmap.width != bounds.width() || bitmap.height != bounds.height() || bounds.isEmpty)
                throw VisualBlocked("screenshotGeometryMismatch")
            val factor = minOf(1.0, 1568.0 / maxOf(bitmap.width, bitmap.height))
            val width = (bitmap.width * factor).roundToInt().coerceAtLeast(1)
            val height = (bitmap.height * factor).roundToInt().coerceAtLeast(1)
            withContext(Dispatchers.IO) {
                val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
                try {
                    file.outputStream().use { if (!scaled.compress(Bitmap.CompressFormat.PNG, 100, it)) throw VisualBlocked("screenshotFailed") }
                    if (file.length() > 4 * 1024 * 1024) throw VisualBlocked("screenshotTooLarge")
                } finally { if (scaled !== bitmap) scaled.recycle() }
            }
            currentCoroutineContext().ensureActive()
            validatePolicy()
            val (finalId, finalBounds) = window(target)
            if (id != finalId || bounds != finalBounds || rotation != rotation()) throw VisualBlocked("targetChanged")
            val frame = VisualFrame(UUID.randomUUID().toString(), target, id, bounds.left, bounds.top,
                bounds.width(), bounds.height(), width, height, rotation, System.currentTimeMillis())
            val artifact = ExecutionArtifact(file.toURI().toString(), "screen-${frame.id}.png", file.length(), localPath = file.path)
            deliveredFile = file
            delivered = true
            return frame to artifact
        } finally {
            bitmap.recycle()
            if (!delivered) file.delete()
        }
    }

    @android.annotation.TargetApi(34)
    private suspend fun screenshot(windowId: Int): Bitmap = suspendCancellableCoroutine { continuation ->
        service.takeScreenshotOfWindow(windowId, service.mainExecutor, object : AccessibilityService.TakeScreenshotCallback {
            override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                val buffer = result.hardwareBuffer
                var software: Bitmap? = null
                try {
                    if (!continuation.isActive) return
                    val hardware = Bitmap.wrapHardwareBuffer(buffer, result.colorSpace) ?: throw VisualBlocked("screenshotFailed")
                    try { software = hardware.copy(Bitmap.Config.ARGB_8888, false) }
                    finally { hardware.recycle() }
                    val image = software ?: throw VisualBlocked("screenshotFailed")
                    continuation.resume(image) { _, bitmap, _ -> bitmap.recycle() }
                    software = null
                } catch (_: Exception) {
                    if (continuation.isActive) continuation.resumeWithException(VisualBlocked("screenshotFailed"))
                } finally { software?.recycle(); buffer.close() }
            }
            override fun onFailure(errorCode: Int) {
                if (continuation.isActive) continuation.resumeWithException(VisualBlocked(
                    if (errorCode == AccessibilityService.ERROR_TAKE_SCREENSHOT_SECURE_WINDOW) "secureWindow" else "screenshotFailed"))
            }
        })
    }

    private suspend fun gesture(step: GestureStep): Boolean = suspendCancellableCoroutine { continuation ->
        val x = step.x!!.toFloat(); val y = step.y!!.toFloat()
        val path = Path().apply {
            moveTo(x, y)
            if (step.type == "swipe") lineTo(step.endX!!.toFloat(), step.endY!!.toFloat())
        }
        val builder = GestureDescription.Builder()
        if (step.type == "double_tap") {
            builder.addStroke(GestureDescription.StrokeDescription(path, 0, 80))
            builder.addStroke(GestureDescription.StrokeDescription(path, 180, 80))
        } else builder.addStroke(GestureDescription.StrokeDescription(path, 0, step.durationMs))
        val sent = service.dispatchGesture(builder.build(), object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) { if (continuation.isActive) continuation.resume(true) }
            override fun onCancelled(gestureDescription: GestureDescription?) { if (continuation.isActive) continuation.resume(false) }
        }, null)
        if (!sent && continuation.isActive) continuation.resume(false)
        // Android exposes no cancellation handle; cancel stops the batch, not an already dispatched stroke.
    }
}

class VisualBlocked(val reason: String) : Exception()
