package app.xiangyue.phase.shizuku

import android.app.ActivityManager
import android.app.ActivityOptions
import android.app.PendingIntent
import android.app.TaskInfo
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.os.*
import android.os.Process
import android.view.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Privileged, run-owned display primitives only. No commands, paths or physical display IDs. */
@androidx.annotation.Keep
class ShizukuDeviceService(private val context: Context) : IDeviceUserService.Stub() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val privileged by lazy {
        if (Process.myUid() == Process.SHELL_UID)
            context.createPackageContext("com.android.shell", Context.CONTEXT_IGNORE_SECURITY)
        else context
    }
    private val displays by lazy { privileged.getSystemService(DisplayManager::class.java) }
    private val activities by lazy { privileged.getSystemService(ActivityManager::class.java) }
    private val owners = ConcurrentHashMap<String, Owner>()
    private val ended = ConcurrentHashMap.newKeySet<String>()
    private val jobs = ConcurrentHashMap<String, Job>()
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private val lock = Any()
    private val taskDisplayId by lazy { TaskInfo::class.java.getField("displayId") }
    private class Owner(val client: IBinder, val death: IBinder.DeathRecipient) {
        val mutex = Mutex()
        val seen = mutableSetOf<String>()
        @Volatile var closed = false
        @Volatile var display: VirtualDisplay? = null
        @Volatile var reader: ImageReader? = null
        var screenshotId: String? = null
    }
    private class DeviceFault(val code: String) : Exception()
    private fun caller() { check(Binder.getCallingUid() == context.applicationInfo.uid) }
    override fun probe(): Bundle {
        caller()
        return Bundle().apply { putInt("uid", Process.myUid()); putString("revision", REVISION) }
    }

    override fun execute(request: Bundle, screenshot: ParcelFileDescriptor, callback: IDeviceCallback, client: IBinder) {
        try {
            caller()
            check(request.getLong("uid", -1) == Process.myUid().toLong())
            check(request.getString("revision") == REVISION)
        }
        catch (error: Exception) { screenshot.close(); throw error }
        val ownerId = request.getString("owner").orEmpty()
        val callId = request.getString("call").orEmpty()
        val key = "$ownerId/$callId"
        val owner: Owner
        try {
            check(ID.matches(ownerId) && ID.matches(callId))
            synchronized(lock) {
                check(ownerId !in ended)
                owner = owners[ownerId] ?: run {
                    val death = IBinder.DeathRecipient { runCatching { releaseOwned(ownerId) } }
                    client.linkToDeath(death, 0)
                    Owner(client, death).also { owners[ownerId] = it }
                }
                check(owner.client == client && !owner.closed && owner.seen.add(callId))
            }
        } catch (error: Exception) { screenshot.close(); throw error }
        val result = Bundle()
        val finished = AtomicBoolean(false)
        fun finish(cancelledBeforeStart: Boolean = false) {
            if (!finished.compareAndSet(false, true)) return
            if (cancelledBeforeStart) {
                result.putBoolean("cancelled", true)
                result.putString("error", "cancelled")
            }
            runCatching { screenshot.close() }
            jobs.remove(key)
            runCatching { callback.finished(result) }
        }
        val job = scope.launch(start = CoroutineStart.LAZY) {
            try {
                withTimeout(12000) {
                    owner.mutex.withLock {
                        checkpoint(owner, key)
                        dispatch(owner, key, request, screenshot, result)
                    }
                }
                result.putBoolean("ok", true)
            } catch (_: TimeoutCancellationException) {
                result.putString("error", "timeout")
            } catch (_: CancellationException) {
                result.putBoolean("cancelled", true)
                result.putString("error", "cancelled")
            } catch (error: DeviceFault) {
                result.putString("error", error.code)
            } catch (error: DisplayTextFault) {
                result.putString("error", error.code)
            } catch (_: SecurityException) {
                result.putString("error", "systemOperationDenied")
            } catch (_: Exception) {
                result.putString("error", "deviceUnavailable")
            } finally {
                finish()
            }
        }
        jobs[key] = job
        // A lazy job cancelled before its body starts must still close the received FD.
        job.invokeOnCompletion { finish(cancelledBeforeStart = true) }
        job.start()
    }

    private suspend fun checkpoint(owner: Owner, key: String) {
        currentCoroutineContext().ensureActive()
        if (owner.closed || key in cancelled) throw CancellationException()
        if (privileged.getSystemService(KeyguardManager::class.java).isKeyguardLocked) throw DeviceFault("locked")
    }
    private fun managed(owner: Owner): VirtualDisplay = owner.display ?: throw DeviceFault("displayMissing")
    private fun foreground(owner: Owner, target: String) {
        val id = managed(owner).display.displayId
        @Suppress("DEPRECATION")
        val task = activities.getRunningTasks(100).firstOrNull { taskDisplayId.getInt(it) == id }
        if (task?.topActivity?.packageName != target) throw DeviceFault("displayTargetChanged")
    }
    private fun create(owner: Owner) {
        if (owner.display != null) return
        val reader = ImageReader.newInstance(WIDTH, HEIGHT, PixelFormat.RGBA_8888, 2)
        try {
            // Required system flags must exist; never silently create a main-focus display on an older ROM.
            // Do not request SECURE: protected content must remain protected by Android.
            val flags = try {
                listOf("PUBLIC", "OWN_CONTENT_ONLY", "SUPPORTS_TOUCH", "DESTROY_CONTENT_ON_REMOVAL",
                    "TRUSTED", "OWN_FOCUS", "STEAL_TOP_FOCUS_DISABLED").fold(0) { bits, name ->
                    bits or DisplayManager::class.java.getDeclaredField("VIRTUAL_DISPLAY_FLAG_$name").getInt(null)
                }
            } catch (_: ReflectiveOperationException) { throw DeviceFault("displayUnsupported") }
            val display = displays.createVirtualDisplay("相月虚拟屏", WIDTH, HEIGHT, 320, reader.surface, flags)
            if (display.display.displayId <= Display.DEFAULT_DISPLAY) {
                display.release()
                throw DeviceFault("deviceUnavailable")
            }
            synchronized(lock) {
                if (owner.closed) { display.release(); throw CancellationException() }
                owner.reader = reader
                owner.display = display
            }
        } catch (error: Exception) { reader.close(); throw error }
    }

    private suspend fun launch(owner: Owner, key: String, target: String, result: Bundle) {
        var pending: PendingIntent? = null
        try {
            val intent = privileged.packageManager.getLaunchIntentForPackage(target)
                ?: throw DeviceFault("notLaunchable")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            val display = managed(owner).display
            if (!display.isValid || display.displayId <= Display.DEFAULT_DISPLAY) throw DeviceFault("displayMissing")
            val options = ActivityOptions.makeBasic().apply { launchDisplayId = display.displayId }
            // A Shizuku UserService is not an ActivityManager-attached app process.
            // PendingIntent avoids Context.startActivity's application-thread caller check.
            val launch = PendingIntent.getActivity(
                privileged.createDisplayContext(display), display.displayId, intent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
            )
            pending = launch
            checkpoint(owner, key)
            owner.screenshotId = null
            result.putBoolean("actionDispatched", true)
            launch.send(privileged, 0, null, null, null, null, options.toBundle())
            result.putBoolean("actionAccepted", true)
        } catch (_: SecurityException) {
            result.putBoolean("actionAccepted", false)
            throw DeviceFault("launchDenied")
        } catch (_: PendingIntent.CanceledException) {
            result.putBoolean("actionAccepted", false)
            throw DeviceFault("launchCancelled")
        } finally {
            // Do not leave a reusable launch token after cancellation or a rejected send.
            pending?.let { runCatching { it.cancel() } }
        }
    }

    private suspend fun dispatch(owner: Owner, key: String, request: Bundle, output: ParcelFileDescriptor, result: Bundle) {
        val action = request.getString("action") ?: throw DeviceFault("invalidArguments")
        val target = request.getString("packageName").orEmpty()
        if (action == "close") { closeDisplay(owner); result.putBoolean("released", true); return }
        if (!PACKAGE.matches(target)) throw DeviceFault("invalidArguments")
        if (action !in setOf("launch", "capture", "tap", "swipe", "key", "text")) throw DeviceFault("invalidArguments")
        if (action == "launch") create(owner) else managed(owner)
        result.putInt("displayId", managed(owner).display.displayId)
        result.putString("packageName", target)
        if (action != "launch") foreground(owner, target)
        if (action !in setOf("launch", "capture")) {
            if (owner.screenshotId == null || request.getString("screenshotId") != owner.screenshotId)
                throw DeviceFault("staleScreenshot")
        }
        suspend fun beforeInput() {
            checkpoint(owner, key)
            foreground(owner, target)
            result.putBoolean("actionDispatched", true)
        }
        when (action) {
            "launch" -> {
                launch(owner, key, target, result)
                val deadline = SystemClock.uptimeMillis() + 4000
                while (true) {
                    checkpoint(owner, key)
                    try { foreground(owner, target); break } catch (error: DeviceFault) {
                        if (SystemClock.uptimeMillis() >= deadline) throw error
                        delay(100)
                    }
                }
                delay(250)
            }
            "tap", "swipe" -> {
                fun coordinate(name: String, maximum: Int): Int {
                    if (!request.containsKey(name)) throw DeviceFault("invalidArguments")
                    val value = request.getInt(name, -1)
                    if (value !in 0 until maximum) throw DeviceFault("invalidArguments")
                    return value
                }
                val x = coordinate("x", WIDTH); val y = coordinate("y", HEIGHT)
                val endX = if (action == "swipe") coordinate("endX", WIDTH) else x
                val endY = if (action == "swipe") coordinate("endY", HEIGHT) else y
                val duration = if (action == "swipe") request.getInt("durationMs", 400) else 60
                if (duration !in 50..2000) throw DeviceFault("invalidArguments")
                owner.screenshotId = null
                beforeInput()
                gesture(owner, key, x, y, endX, endY, duration) { beforeInput() }
                result.putBoolean("actionAccepted", true)
            }
            "text" -> {
                val text = request.getString("text").orEmpty()
                if (text.isEmpty() || text.length > 500 || '\u0000' in text) throw DeviceFault("invalidArguments")
                DisplayTextInput.insert(privileged, managed(owner).display, target, text, result,
                    validate = { checkpoint(owner, key); foreground(owner, target) },
                    beforeDispatch = { owner.screenshotId = null })
            }
            "key" -> {
                val code = KEYS[request.getString("key")] ?: throw DeviceFault("invalidArguments")
                val now = SystemClock.uptimeMillis()
                val events = arrayOf(KeyEvent(now, now, KeyEvent.ACTION_DOWN, code, 0), KeyEvent(now, now, KeyEvent.ACTION_UP, code, 0))
                owner.screenshotId = null
                val held = linkedMapOf<Int, KeyEvent>()
                try {
                    for (event in events) {
                        beforeInput()
                        val now = SystemClock.uptimeMillis()
                        val downTime = held[event.keyCode]?.downTime ?: now
                        val value = KeyEvent(downTime, now, event.action, event.keyCode, 0, event.metaState,
                            KeyCharacterMap.VIRTUAL_KEYBOARD, event.scanCode, event.flags, InputDevice.SOURCE_KEYBOARD)
                        inject(owner, value)
                        if (value.action == KeyEvent.ACTION_DOWN) held[value.keyCode] = value else held.remove(value.keyCode)
                        delay(4)
                    }
                } finally {
                    held.values.toList().asReversed().forEach { event ->
                        runCatching { inject(owner, KeyEvent.changeAction(event, KeyEvent.ACTION_UP)) }
                    }
                }
                result.putBoolean("actionAccepted", true)
            }
        }
        if (action != "capture") delay(180)
        try {
            checkpoint(owner, key)
            foreground(owner, target)
            capture(owner, key, target, output, result)
        } catch (error: CancellationException) { throw error }
        catch (error: Exception) {
            owner.screenshotId = null
            if (action == "capture") throw error
            result.putString("observationError", (error as? DeviceFault)?.code ?: "screenshotFailed")
        }
    }

    private suspend fun gesture(owner: Owner, key: String, x: Int, y: Int, endX: Int, endY: Int, duration: Int, validate: suspend () -> Unit) {
        val down = SystemClock.uptimeMillis()
        var pressed = false
        fun send(action: Int, px: Float, py: Float) {
            val event = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action, px, py, 0)
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            try { inject(owner, event) } finally { event.recycle() }
        }
        try {
            send(MotionEvent.ACTION_DOWN, x.toFloat(), y.toFloat()); pressed = true
            val steps = (duration / 16).coerceAtLeast(1)
            for (step in 1..steps) {
                delay((duration / steps).toLong())
                checkpoint(owner, key); validate()
                val fraction = step.toFloat() / steps
                if (step < steps) send(MotionEvent.ACTION_MOVE, x + (endX - x) * fraction, y + (endY - y) * fraction)
            }
            send(MotionEvent.ACTION_UP, endX.toFloat(), endY.toFloat()); pressed = false
        } finally {
            if (pressed) runCatching { send(MotionEvent.ACTION_CANCEL, x.toFloat(), y.toFloat()) }
        }
    }
    private fun inject(owner: Owner, event: InputEvent) {
        if (owner.closed) throw CancellationException()
        val display = managed(owner).display
        if (!display.isValid || display.displayId <= Display.DEFAULT_DISPLAY) throw DeviceFault("displayMissing")
        val id = display.displayId
        InputEvent::class.java.getDeclaredMethod("setDisplayId", Int::class.javaPrimitiveType).apply { isAccessible = true }.invoke(event, id)
        val type = Class.forName("android.hardware.input.InputManager")
        val manager = type.getDeclaredMethod("getInstance").apply { isAccessible = true }.invoke(null)
        val accepted = type.getMethod("injectInputEvent", InputEvent::class.java, Int::class.javaPrimitiveType).invoke(manager, event, 2)
        if (accepted != true) throw DeviceFault("inputRejected")
    }
    private suspend fun capture(owner: Owner, key: String, target: String, output: ParcelFileDescriptor, result: Bundle) {
        managed(owner)
        val reader = ImageReader.newInstance(WIDTH, HEIGHT, PixelFormat.RGBA_8888, 2)
        try {
            synchronized(lock) {
                if (owner.closed) throw CancellationException()
                val previous = owner.reader
                // A fresh non-null surface requests a frame without switching the display off.
                managed(owner).surface = reader.surface
                owner.reader = reader
                previous?.close()
            }
        } catch (error: Exception) { reader.close(); throw error }
        val deadline = SystemClock.uptimeMillis() + 2500
        var image = reader.acquireLatestImage()
        while (image == null) {
            checkpoint(owner, key)
            if (SystemClock.uptimeMillis() >= deadline) throw DeviceFault("screenshotFailed")
            delay(30)
            image = reader.acquireLatestImage()
        }
        val bytes = try {
            if (image.width != WIDTH || image.height != HEIGHT) throw DeviceFault("screenshotFailed")
            val plane = image.planes.singleOrNull() ?: throw DeviceFault("screenshotFailed")
            if (plane.pixelStride != 4 || plane.rowStride < WIDTH * 4) throw DeviceFault("screenshotFailed")
            val pixels = ByteBuffer.allocate(WIDTH * HEIGHT * 4)
            val source = plane.buffer.duplicate()
            // The last image row need not include its padding; copy only actual pixels.
            for (row in 0 until HEIGHT) {
                currentCoroutineContext().ensureActive()
                if (owner.closed || key in cancelled) throw CancellationException()
                val start = row * plane.rowStride
                val end = start + WIDTH * 4
                if (end > source.capacity()) throw DeviceFault("screenshotFailed")
                source.limit(source.capacity()); source.position(start); source.limit(end)
                pixels.put(source)
            }
            pixels.flip()
            val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
            try {
                bitmap.copyPixelsFromBuffer(pixels)
                val buffer = ByteArrayOutputStream()
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, buffer)) throw DeviceFault("screenshotFailed")
                buffer.toByteArray().also { if (it.size > 4 * 1024 * 1024) throw DeviceFault("screenshotTooLarge") }
            } finally { bitmap.recycle() }
        } finally { image.close() }
        checkpoint(owner, key); foreground(owner, target)
        ParcelFileDescriptor.AutoCloseOutputStream(output).use { it.write(bytes) }
        val snapshot = UUID.randomUUID().toString()
        owner.screenshotId = snapshot
        result.putString("screenshotId", snapshot)
        result.putInt("imageWidth", WIDTH); result.putInt("imageHeight", HEIGHT)
    }
    override fun cancel(owner: String, call: String) {
        caller()
        val key = "$owner/$call"
        cancelled.add(key)
        jobs[key]?.cancel()
    }
    private fun closeDisplay(owner: Owner) = synchronized(lock) {
        owner.screenshotId = null
        var failed = false
        try { owner.display?.release(); owner.display = null } catch (_: Exception) { failed = true }
        try { owner.reader?.close(); owner.reader = null } catch (_: Exception) { failed = true }
        if (failed) throw DeviceFault("displayReleaseFailed")
    }
    private fun releaseOwned(ownerId: String) {
        ended.add(ownerId)
        synchronized(lock) {
            owners.remove(ownerId)?.let { owner ->
                owner.closed = true
                jobs.filterKeys { it.startsWith("$ownerId/") }.values.forEach { it.cancel() }
                try { closeDisplay(owner) }
                finally { runCatching { owner.client.unlinkToDeath(owner.death, 0) } }
            }
        }
    }
    override fun release(owner: String) { caller(); releaseOwned(owner) }
    override fun destroy() {
        check(Binder.getCallingUid() in setOf(context.applicationInfo.uid, Process.myUid(), 0))
        owners.keys.toList().forEach { runCatching { releaseOwned(it) } }
        scope.cancel()
        kotlin.system.exitProcess(0)
    }
    companion object {
        const val REVISION = "virtual-display-1"
        const val WIDTH = 720
        const val HEIGHT = 1280
        private val ID = Regex("[a-zA-Z0-9_-]{1,100}")
        private val PACKAGE = Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+")
        private val KEYS = mapOf("back" to KeyEvent.KEYCODE_BACK, "enter" to KeyEvent.KEYCODE_ENTER,
            "tab" to KeyEvent.KEYCODE_TAB, "delete" to KeyEvent.KEYCODE_DEL, "escape" to KeyEvent.KEYCODE_ESCAPE,
            "up" to KeyEvent.KEYCODE_DPAD_UP, "down" to KeyEvent.KEYCODE_DPAD_DOWN,
            "left" to KeyEvent.KEYCODE_DPAD_LEFT, "right" to KeyEvent.KEYCODE_DPAD_RIGHT)
    }
}
