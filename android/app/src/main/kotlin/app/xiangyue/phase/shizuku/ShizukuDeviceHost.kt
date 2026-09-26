package app.xiangyue.phase.shizuku

import android.app.KeyguardManager
import android.content.Context
import android.os.*
import app.xiangyue.phase.bridge.*
import app.xiangyue.phase.bridge.commands.CommandChannelStatus
import java.io.File
import java.util.UUID
import kotlinx.coroutines.*
import rikka.shizuku.Shizuku

/** App-process checks and lifecycle; the privileged service never owns conversation state. */
class ShizukuDeviceHost(private val context: Context, private val stopped: (String, String) -> Unit) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    var onStatusChanged: () -> Unit = {}
    private val connection = ShizukuConnection(context, { onStatusChanged() }) {
        scope.launch { owners.keys.toList().forEach { stop(it, "channelDisconnected") } }
    }
    @Volatile private var enabled = false
    private class Owner(val uid: Long, val allowed: suspend (String) -> Boolean) {
        val client = Binder()
        var target: String? = null
        var monitor: Job? = null
    }
    private val owners = mutableMapOf<String, Owner>()
    private val ended = mutableSetOf<String>()
    fun status(): CommandChannelStatus {
        val uid = connection.uid()
        return when {
            Build.VERSION.SDK_INT < 30 -> CommandChannelStatus("shizuku", "unsupported", "虚拟屏需要 Android 11 或更高版本")
            !runCatching { context.packageManager.getApplicationInfo("moe.shizuku.privileged.api", 0) }.isSuccess -> CommandChannelStatus("shizuku", "notInstalled", "未安装 Shizuku")
            !connection.running() -> CommandChannelStatus("shizuku", "notRunning", "Shizuku 未运行")
            !connection.permission() -> CommandChannelStatus("shizuku", "permissionRequired", "未授权 Shizuku")
            uid < 0 -> CommandChannelStatus("shizuku", "unavailable", "无法读取 Shizuku 执行身份")
            else -> CommandChannelStatus("shizuku", "ready", "已授权", uid.toLong(), ShizukuDeviceService.REVISION, "")
        }
    }
    fun available() = enabled && status().state == "ready"
    fun authorize() {
        check(connection.running())
        Shizuku.requestPermission(4601)
    }
    suspend fun initialize() {
        val reply = withContext(Dispatchers.IO) { connection.get().probe() }
        check(reply.getInt("uid") == connection.uid() && reply.getString("revision") == ShizukuDeviceService.REVISION)
    }
    suspend fun setEnabled(value: Boolean) = withContext(Dispatchers.Main.immediate) {
        enabled = value
        if (!value) owners.keys.toList().forEach { stop(it, "channelDisabled") }
    }
    private fun locked() = context.getSystemService(KeyguardManager::class.java).isKeyguardLocked
    private fun permitted(uid: Long) = available() && connection.uid().toLong() == uid
    private suspend fun allowedNow(owner: Owner, target: String): Boolean = try {
        owner.allowed(target)
    } catch (error: CancellationException) { throw error } catch (_: Exception) { false }
    private fun cacheDirectory(owner: String) = File(context.cacheDir, "virtual-display/$owner")

    suspend fun execute(request: ExecutionRequest, allowed: suspend (String) -> Boolean, checkpoint: (Map<String, Any?>) -> Unit): ExecutionResult {
        if (!Regex("[a-zA-Z0-9_-]{1,100}").matches(request.runId)) return failure(request, "invalidArguments")
        val uid = (request.arguments["uid"] as? Number)?.toLong() ?: return failure(request, "identityChanged")
        if (request.arguments["revision"] != ShizukuDeviceService.REVISION || !permitted(uid)) return failure(request, "identityChanged")
        if (request.runId in ended) return failure(request, "cancelled")
        if (locked()) return failure(request, "locked")
        val action = request.arguments["action"] as? String ?: return failure(request, "invalidArguments")
        val target = request.target.packageName
        if (request.arguments["packageName"] != target || action !in setOf("launch", "capture", "tap", "swipe", "key", "text", "close")) return failure(request, "invalidArguments")
        if (action != "close" && (target.isNullOrBlank() || !allowed(target))) return failure(request, "applicationDenied")
        val owner = owners.getOrPut(request.runId) { Owner(uid, allowed) }
        if (owner.uid != uid) return failure(request, "identityChanged")
        if (owner.monitor == null) owner.monitor = scope.launch {
            while (isActive && owners[request.runId] === owner) {
                delay(500)
                val reason = when {
                    !permitted(uid) -> "permissionRequired"
                    locked() -> "locked"
                    owner.target != null && !allowedNow(owner, owner.target!!) -> "applicationDenied"
                    else -> null
                }
                if (reason != null) { stop(request.runId, reason); break }
            }
        }
        val directory = cacheDirectory(request.runId)
        val image = File(directory, "${UUID.randomUUID()}.png")
        var retained = false
        var dispatched = false
        var remote: IDeviceUserService? = null
        val result = CompletableDeferred<Bundle>()
        try {
            if (!directory.isDirectory && !directory.mkdirs()) return failure(request, "screenshotStorage")
            remote = connection.get()
            currentCoroutineContext().ensureActive()
            if (owners[request.runId] !== owner || !permitted(uid)) return failure(request, "permissionRequired")
            if (action != "close" && !allowed(target!!)) return failure(request, "applicationDenied")
            owner.target = if (action == "close") null else target
            ParcelFileDescriptor.open(image, ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_TRUNCATE or ParcelFileDescriptor.MODE_WRITE_ONLY).use { fd ->
                val spec = Bundle().apply {
                    putString("owner", request.runId); putString("call", request.toolCallId); putLong("uid", uid)
                    for ((key, value) in request.arguments) when (value) {
                        is String -> putString(key, value)
                        is Long -> if (key != "uid") { require(value in Int.MIN_VALUE..Int.MAX_VALUE); putInt(key, value.toInt()) }
                        is Int -> if (key != "uid") putInt(key, value)
                    }
                }
                checkpoint(mapOf("packageName" to target, "dispatchRequested" to true))
                dispatched = true
                withContext(Dispatchers.IO) { remote.execute(spec, fd, object : IDeviceCallback.Stub() {
                    override fun finished(value: Bundle) { result.complete(value) }
                }, owner.client) }
            }
            val reply = withTimeout(15000) { result.await() }
            currentCoroutineContext().ensureActive()
            if (!permitted(uid) || owners[request.runId] !== owner) return failure(request, "permissionRequired", dispatched)
            if (action != "close" && !allowed(target!!)) return failure(request, "applicationDenied", dispatched)
            currentCoroutineContext().ensureActive()
            if (locked()) { stop(request.runId, "locked"); return failure(request, "locked", dispatched) }
            val details = mutableMapOf<String, Any?>("action" to action, "packageName" to target)
            for (key in listOf("actionDispatched", "actionAccepted", "released")) if (reply.containsKey(key)) details[key] = reply.getBoolean(key)
            if (reply.containsKey("displayId")) details["displayId"] = reply.getInt("displayId")
            reply.getString("observationError")?.let { details["observationError"] = reason(it) }
            val artifacts = mutableListOf<ExecutionArtifact>()
            val snapshot = reply.getString("screenshotId")
            if (reply.getBoolean("ok") && snapshot != null && image.length() in 1..(4L * 1024 * 1024)) {
                details["screenshot"] = mapOf("screenshotId" to snapshot, "packageName" to target,
                    "displayId" to reply.getInt("displayId"), "imageWidth" to reply.getInt("imageWidth"),
                    "imageHeight" to reply.getInt("imageHeight"), "coordinateSpace" to "image_pixels")
                artifacts += ExecutionArtifact(image.toURI().toString(), image.name, image.length(), localPath = image.path)
                retained = true
            }
            if (reply.getBoolean("ok") && action != "close" && artifacts.isEmpty() && !details.containsKey("observationError")) {
                if (action == "capture") return failure(request, "screenshotFailed", dispatched)
                details["observationError"] = reason("screenshotFailed")
            }
            val code = reply.getString("error")
            if (code != null) details["reason"] = reason(code)
            val status = when {
                reply.getBoolean("cancelled") -> ExecutionStatus.CANCELLED
                reply.getBoolean("ok") -> ExecutionStatus.SUCCEEDED
                else -> ExecutionStatus.FAILED
            }
            return ExecutionResult(request.toolCallId, status, details, artifacts,
                if (status == ExecutionStatus.SUCCEEDED) null else if (status == ExecutionStatus.CANCELLED) ChannelError.CANCELLED else ChannelError.EXECUTION_FAILED)
        } catch (error: CancellationException) { throw error }
        catch (_: java.io.IOException) { return failure(request, "screenshotStorage", dispatched) }
        catch (_: Exception) { return failure(request, "deviceUnavailable", dispatched) }
        finally {
            if (!result.isCompleted && dispatched) withContext(NonCancellable + Dispatchers.IO) {
                runCatching { remote?.cancel(request.runId, request.toolCallId) }
            }
            if (!retained) image.delete()
        }
    }
    fun endOwner(ownerId: String) {
        val owner = owners.remove(ownerId) ?: return
        ended.add(ownerId)
        owner.monitor?.cancel()
        val remote = connection.remote
        scope.launch {
            withContext(Dispatchers.IO) {
                runCatching { remote?.release(ownerId) }
                cacheDirectory(ownerId).deleteRecursively()
            }
            if (owners.isEmpty() && remote != null) connection.disconnect(remote)
        }
    }
    private fun stop(owner: String, reason: String) {
        endOwner(owner)
        stopped(owner, if (reason == "permissionRequired") "shizukuPermissionRequired" else reason)
    }
    suspend fun policyChanged() {
        for ((id, owner) in owners.toMap()) {
            val target = owner.target ?: continue
            if (!allowedNow(owner, target)) stop(id, "applicationDenied")
        }
    }
    private fun failure(request: ExecutionRequest, code: String, dispatched: Boolean = false) = ExecutionResult(
        request.toolCallId, ExecutionStatus.FAILED,
        mapOf("reason" to reason(code), "dispatchRequested" to dispatched), emptyList(), ChannelError.EXECUTION_FAILED)
    companion object {
        fun reason(code: String): String = when (code) {
            "identityChanged" -> "Shizuku 执行身份或设备组件已改变，请开始新运行"
            "permissionRequired", "channelDisabled" -> "Shizuku 虚拟屏未启用或授权已撤销"
            "applicationDenied" -> "目标应用未被当前应用名单允许"
            "displayUnsupported" -> "此系统不支持所需的独立焦点虚拟屏，未改用主屏"
            "displayReleaseFailed" -> "未收到虚拟屏资源释放的完整回执"
            "displayMissing" -> "本次运行还没有虚拟屏，请先启动允许的应用"
            "displayTargetChanged" -> "虚拟屏前台任务不属于目标应用，未继续操作或返回截图"
            "staleScreenshot" -> "虚拟屏截图已过期，请重新观察后操作"
            "textUnsupported" -> "系统键盘无法输入这些字符；未输入文字，不会改用剪贴板"
            "notLaunchable" -> "此应用没有可启动的界面"
            "inputRejected" -> "系统拒绝了虚拟屏输入，未重试动作"
            "screenshotFailed" -> "未取得虚拟屏截图，可重新观察；不要重放此前已派发的动作"
            "screenshotStorage" -> "无法创建或读取虚拟屏截图临时文件"
            "timeout" -> "虚拟屏操作超时，已派发动作不代表已撤销"
            "screenshotTooLarge" -> "虚拟屏截图超过 4MB，未返回图片"
            "locked" -> "设备已锁定，虚拟屏操作已停止"
            "invalidArguments" -> "虚拟屏动作参数无效"
            "cancelled" -> "虚拟屏操作已停止，已派发动作不代表已撤销"
            else -> "Shizuku 虚拟屏暂不可用，请检查授权、服务和设备支持情况"
        }
    }
}
