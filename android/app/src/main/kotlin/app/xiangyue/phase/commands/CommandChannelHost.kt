package app.xiangyue.phase.commands

import android.app.Activity
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.util.Base64
import app.xiangyue.phase.bridge.commands.*
import java.io.*
import java.lang.ref.WeakReference
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.*
import kotlinx.coroutines.selects.select
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import rikka.shizuku.Shizuku

class CommandChannelHost(
    private val context: Context, private val flutter: CommandChannelFlutterApi,
    private val ownerActive: (String) -> Boolean,
) : CommandChannelHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var activity = WeakReference<Activity>(null)
    @Volatile private var enabled = emptySet<String>()
    private val active = ConcurrentHashMap<String, Operation>()
    private val seen = ConcurrentHashMap.newKeySet<String>()
    private val termux = TermuxTransport(context)
    private val setupMutex = Mutex()
    private val shizuku = ShizukuConnection(context, ::changed) { stopChannel("shizuku", "channelDisconnected") }
    private val client = Binder()
    private var termuxReady: String? = null
    private val idPattern = Regex("[a-zA-Z0-9_-]{1,100}")
    fun attach(value: Activity) { activity = WeakReference(value); changed() }
    fun detach(value: Activity) { if (activity.get() === value) activity.clear() }
    fun changed() { scope.launch(Dispatchers.Main) { runCatching { flutter.statusChanged() } } }
    private fun fail(code: String, message: String): Nothing = throw FlutterError(code, message, null)
    private fun supported() = Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a" && termux.packaged.canExecute()
    override suspend fun status(): List<CommandChannelStatus> = withContext(Dispatchers.IO) {
        val installed = runCatching { context.packageManager.getApplicationInfo("moe.shizuku.privileged.api", 0) }.isSuccess
        val s = when {
            !supported() -> CommandChannelStatus("shizuku", "unsupported", "此设备不支持命令运行组件")
            !installed -> CommandChannelStatus("shizuku", "notInstalled", "未安装 Shizuku")
            !shizuku.running() -> CommandChannelStatus("shizuku", "notRunning", "Shizuku 未运行")
            !shizuku.permission() -> CommandChannelStatus("shizuku", "permissionRequired", "未授权 Shizuku")
            shizuku.uid() != 2000 -> CommandChannelStatus("shizuku", "identityUnsupported", "仅支持 shell 身份的 Shizuku")
            else -> CommandChannelStatus("shizuku", "ready", "已授权", 2000, termux.revision, "/")
        }
        val t = when {
            !supported() -> CommandChannelStatus("termux", "unsupported", "此设备不支持命令运行组件")
            !termux.installed() -> CommandChannelStatus("termux", "notInstalled", "未安装 Termux")
            !termux.permitted() -> { termuxReady = null; CommandChannelStatus("termux", "permissionRequired", "未授权 Termux 命令权限") }
            else -> {
                if (termuxReady == null && "termux" in enabled) runCatching { termux.probe(); termuxReady = termux.revision }
                if (termuxReady == termux.revision) CommandChannelStatus("termux", "ready", "运行组件已就绪", termux.uid().toLong(), termux.revision, TermuxTransport.HOME)
                else CommandChannelStatus("termux", "initializationRequired", "需要初始化运行组件并允许外部调用")
            }
        }
        listOf(s, t)
    }
    override suspend fun authorize(channel: String) = withContext(Dispatchers.Main) {
        val host = activity.get() ?: fail("unavailable", "请返回相月后授权")
        when (channel) {
            "shizuku" -> { if (!shizuku.running()) fail("notRunning", "请先启动 Shizuku"); Shizuku.requestPermission(4601) }
            "termux" -> { if (!termux.installed()) fail("notInstalled", "请先安装 Termux"); host.requestPermissions(arrayOf(TermuxTransport.PERMISSION), 4602) }
            else -> fail("invalidChannel", "命令通道无效")
        }
    }
    override suspend fun initialize(channel: String) = setupMutex.withLock {
        try {
            check(supported())
            when (channel) {
                "shizuku" -> { val reply = withContext(Dispatchers.IO) { shizuku.get().probe() }; check(reply.getBoolean("available") && reply.getInt("uid") == 2000) }
                "termux" -> {
                    check(active.values.none { it.channel == "termux" })
                    termux.initialize(); termuxReady = termux.revision
                }
                else -> error("invalidChannel")
            }
        } catch (_: Exception) { fail("initializationFailed", if (channel == "termux") "Termux 初始化失败，请检查外部调用设置、权限与所需程序" else "Shizuku 连接失败，请检查服务及授权") }
        finally { changed() }
    }
    override fun openSettings(channel: String) {
        val intent = when (channel) {
            "shizuku" -> context.packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")
                ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/"))
            "termux" -> context.packageManager.getLaunchIntentForPackage(TermuxTransport.PACKAGE)
                ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/termux/termux-app/releases"))
            "permissions" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
            else -> null
        } ?: fail("notInstalled", "未找到对应应用")
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
    override suspend fun setEnabled(channels: List<String>) {
        require(channels.all { it == "shizuku" || it == "termux" })
        val old = enabled; enabled = channels.toSet()
        (old - enabled).forEach { stopChannel(it, "channelDisabled") }
    }
    private fun permitted(channel: String) = channel in enabled && when (channel) {
        "shizuku" -> shizuku.permission() && shizuku.uid() == 2000
        "termux" -> termux.permitted()
        else -> false
    }
    private fun validate(owner: String, call: String, channel: String, revision: String, uid: Long) {
        if (!idPattern.matches(owner) || !idPattern.matches(call) || !ownerActive(owner)) fail("invalidOwner", "命令任务归属无效")
        if (!permitted(channel)) fail("permissionRequired", "命令通道未启用或授权已撤销")
        if (!supported() || revision != termux.revision || uid != (if (channel == "shizuku") 2000L else termux.uid().toLong())) fail("identityChanged", "执行身份或运行组件已改变，请开始新运行")
    }
    private inner class Operation(val owner: String, val call: String, val channel: String) {
        @Volatile var cancelled = false
        @Volatile var reason: String? = null
        var stopAction: suspend () -> Unit = {}
        val resources = CopyOnWriteArrayList<Closeable>()
        val done = CompletableDeferred<Unit>()
        val lost = CompletableDeferred<Unit>()
        private val events = Mutex()
        private var sequence = 0L
        private var terminal = false
        private var transferred = 0L
        suspend fun emit(kind: CommandEventKind, bytes: ByteArray? = null, result: Bundle? = null, progress: Long = 0) = events.withLock {
            if (terminal) return@withLock
            if (kind == CommandEventKind.PROGRESS) transferred = progress
            if (kind == CommandEventKind.EXITED) terminal = true
            val event = ExternalCommandEvent(owner, call, sequence++, kind, bytes,
                result?.takeIf { it.containsKey("exitCode") }?.getInt("exitCode")?.toLong(),
                result?.takeIf { it.containsKey("signal") }?.getInt("signal")?.toLong(),
                reason ?: result?.getString("error"),
                result?.takeIf { it.containsKey("bytes") }?.getLong("bytes") ?: transferred,
                result?.getStringArrayList("completedPaths")?.toList() ?: emptyList(),
                cancelled || result?.getBoolean("cancelled") == true,
                result?.getBoolean("outputLimitExceeded") == true,
                result?.getBoolean("terminationAcknowledged") == true)
            withContext(Dispatchers.Main) { withTimeout(10000) { flutter.event(event) } }
        }
        suspend fun stop(error: String? = null) {
            cancelled = true; reason = error ?: reason
            if (error != null) { lost.complete(Unit); close() }
            runCatching { withTimeout(5000) { stopAction() } }
        }
        fun check() { if (cancelled) throw CancellationException(); if (!permitted(channel)) throw IllegalStateException("permissionRequired") }
        fun close() { resources.forEach { runCatching { it.close() } }; resources.clear() }
    }
    private fun register(owner: String, call: String, channel: String, action: suspend (Operation) -> Bundle) {
        check(seen.add(call)) { "alreadyDispatched" }
        val op = Operation(owner, call, channel); check(active.putIfAbsent(call, op) == null)
        scope.launch {
            val permissionMonitor = launch {
                while (isActive) {
                    delay(1000)
                    if (!permitted(channel)) {
                        op.stop("permissionRequired")
                        withContext(Dispatchers.Main) { runCatching { flutter.ownerStopped(owner) } }
                        break
                    }
                }
            }
            var result = Bundle()
            try { op.check(); result = action(op) }
            catch (error: Exception) {
                if (error is CancellationException) op.cancelled = true
                result.putString("error", when (error) { is TransferFault -> error.code; is CommandTransportFault -> error.code; else -> "channelDisconnected" })
                if (error is TransferFault) { result.putStringArrayList("completedPaths", ArrayList(error.report.paths)); result.putLong("bytes", error.report.bytes) }
                runCatching { withTimeout(5000) { op.stopAction() } }
            } finally {
                permissionMonitor.cancel()
                op.close()
                runCatching { op.emit(CommandEventKind.EXITED, result = result) }
                active.remove(call, op); op.done.complete(Unit)
            }
        }
    }
    override suspend fun start(spec: ExternalCommandSpec) {
        validate(spec.ownerId, spec.callId, spec.channel, spec.revision, spec.uid)
        require(spec.command.toByteArray().size <= 120 * 1024 && '\u0000' !in spec.command && spec.cwd.startsWith('/') && '\u0000' !in spec.cwd && spec.outputLimitBytes in 1..(64L * 1024 * 1024))
        register(spec.ownerId, spec.callId, spec.channel) { op ->
            if (spec.channel == "shizuku") shizukuCommand(spec, op) else termuxCommand(spec, op)
        }
    }
    private suspend fun shizukuCommand(spec: ExternalCommandSpec, op: Operation): Bundle = coroutineScope {
        val service = shizuku.get()
        val result = CompletableDeferred<Bundle>()
        val stdout = ParcelFileDescriptor.createPipe(); val stderr = ParcelFileDescriptor.createPipe()
        val out = ParcelFileDescriptor.AutoCloseInputStream(stdout[0]); val err = ParcelFileDescriptor.AutoCloseInputStream(stderr[0])
        op.resources += out; op.resources += err
        val callback = object : ICommandCallback.Stub() { override fun finished(value: Bundle) { result.complete(value) } }
        op.stopAction = { withContext(Dispatchers.IO) { service.cancel(op.owner, op.call) } }
        val monitor = launch {
            while (isActive) { delay(1000); if (!permitted(op.channel)) {
                op.stop("permissionRequired"); result.completeExceptionally(IllegalStateException("permissionRequired")); op.close(); break
            } }
        }
        try {
            op.check()
            withContext(Dispatchers.IO) { service.start(Bundle().apply {
                putString("owner", op.owner); putString("call", op.call); putString("token", TermuxResults.token())
                putString("command", spec.command); putString("cwd", spec.cwd); putLong("limit", spec.outputLimitBytes)
            }, stdout[1], stderr[1], callback, client) }
            stdout[1].close(); stderr[1].close()
            if (op.cancelled) op.stopAction()
            suspend fun pump(input: InputStream, kind: CommandEventKind) {
                val buffer = ByteArray(16384)
                while (true) { val n = withContext(Dispatchers.IO) { input.read(buffer) }; if (n < 0) break; op.emit(kind, buffer.copyOf(n)) }
            }
            val a = async(Dispatchers.IO) { pump(out, CommandEventKind.STDOUT) }
            val b = async(Dispatchers.IO) { pump(err, CommandEventKind.STDERR) }
            val final = select<Bundle> {
                result.onAwait { it }
                op.lost.onAwait { throw IllegalStateException("channelDisconnected") }
            }
            a.await(); b.await(); final
        } finally { monitor.cancel(); runCatching { stdout[1].close() }; runCatching { stderr[1].close() }; op.close() }
    }
    private suspend fun termuxCommand(spec: ExternalCommandSpec, op: Operation): Bundle {
        val token = TermuxResults.token()
        val identity = listOf(TermuxTransport.JOBS, op.call, token)
        var started: TermuxRequest? = null
        var settled = false
        op.stopAction = { termux.call(listOf("cancel") + identity) }
        try {
            termux.call(listOf("prepare") + identity + listOf(spec.cwd, "${TermuxTransport.PREFIX}/bin/bash", TermuxTransport.HOME,
                "${TermuxTransport.PREFIX}/bin:/system/bin", spec.outputLimitBytes.toString(), (SystemClock.elapsedRealtime() + 30000).toString()), spec.command)
            if (op.cancelled) { settled = true; return Bundle().apply { putBoolean("cancelled", true); putBoolean("terminationAcknowledged", true) } }
            op.check()
            started = withContext(Dispatchers.Main) { termux.dispatch(termux.executable, listOf("run") + identity) }
            if (op.cancelled) runCatching { op.stopAction() }
            var outOffset = 0L; var errOffset = 0L
            while (true) {
                if (op.lost.isCompleted) throw CommandTransportFault("cleanupIncomplete")
                if (!permitted(op.channel)) { op.cancelled = true; error("permissionRequired") }
                val page = termux.call(listOf("poll") + identity + listOf(outOffset.toString(), errOffset.toString(), if (op.cancelled) "read" else "renew"))
                check(page.getLong("outOffset") == outOffset && page.getLong("errOffset") == errOffset)
                fun decode(name: String): ByteArray {
                    val encoded = page.getString(name); val bytes = Base64.decode(encoded, Base64.NO_WRAP)
                    check(bytes.size <= 8192 && Base64.encodeToString(bytes, Base64.NO_WRAP) == encoded)
                    return bytes
                }
                val out = decode("stdout"); val err = decode("stderr")
                if (out.isNotEmpty()) op.emit(CommandEventKind.STDOUT, out)
                if (err.isNotEmpty()) op.emit(CommandEventKind.STDERR, err)
                outOffset += out.size; errOffset += err.size
                val result = page.getJSONObject("result")
                if (result.getString("state") == "exited" &&
                    ((out.isEmpty() && err.isEmpty()) || op.cancelled)) {
                    settled = true
                    return CommandUserService.jsonResult(result).apply {
                        if (op.cancelled && (out.isNotEmpty() || err.isNotEmpty())) {
                            putString("error", "outputStopped")
                        }
                    }
                }
                if (started.result.isCompleted) {
                    val launch = started.result.await()
                    check(launch.error == -1 && launch.exitCode == 0) { "termuxLaunchFailed" }
                }
                delay(if (out.isNotEmpty() || err.isNotEmpty()) 10 else 1000)
            }
        } finally {
            if (!settled) runCatching { withTimeout(5000) { op.stopAction() } }
            started?.close()
            if (settled) runCatching { termux.call(listOf("cleanup") + identity) }
        }
    }
    override suspend fun transfer(spec: ChannelTransferSpec) {
        validate(spec.ownerId, spec.callId, spec.channel, spec.revision, spec.uid)
        val root = File(spec.localRoot).canonicalFile
        val allowed = File(context.noBackupFilesDir, "linux/workspaces").canonicalPath + "/"
        require(root.path.startsWith(allowed) && root.isDirectory && spec.path.isNotBlank() && !spec.path.startsWith('/') && spec.path.split('/').none { it == ".." } && '\u0000' !in spec.path && '\\' !in spec.path)
        val local = File(root, spec.path.split('/').filter { it.isNotEmpty() && it != "." }.joinToString("/"))
        require(local.canonicalPath == root.path || local.canonicalPath.startsWith(root.path + "/"))
        require(spec.remotePath.startsWith('/') && '\u0000' !in spec.remotePath && spec.fileLimitBytes in 1..(64L*1024*1024) && spec.totalLimitBytes in 1..(256L*1024*1024) && spec.entryLimit in 1..1000)
        register(spec.ownerId, spec.callId, spec.channel) { op ->
            if (spec.channel == "shizuku") shizukuTransfer(spec, local, op) else termuxTransfer(spec, local, op)
        }
    }
    private fun reportBundle(report: TransferReport) = Bundle().apply {
        putLong("bytes", report.bytes); putStringArrayList("completedPaths", ArrayList(report.paths)); putBoolean("terminationAcknowledged", true)
    }
    private fun copy(spec: ChannelTransferSpec, local: File, op: Operation, input: InputStream, output: OutputStream): TransferReport {
        var last = 0L
        return FileTransferProtocol.copy(input, output, local, spec.toChannel,
            TransferLimits(spec.fileLimitBytes, spec.totalLimitBytes, spec.entryLimit.toInt()), op::check) { bytes ->
            if (SystemClock.elapsedRealtime() - last >= 300) {
                last = SystemClock.elapsedRealtime(); runBlocking { op.emit(CommandEventKind.PROGRESS, progress = bytes) }
            }
        }
    }
    private suspend fun shizukuTransfer(spec: ChannelTransferSpec, local: File, op: Operation): Bundle {
        val service = shizuku.get(); val pair = ParcelFileDescriptor.createSocketPair()
        val input = ParcelFileDescriptor.AutoCloseInputStream(pair[0]); val output = ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(pair[0].fileDescriptor))
        op.resources += input; op.resources += output
        val result = CompletableDeferred<Bundle>()
        op.stopAction = { op.close(); withContext(Dispatchers.IO) { service.cancel(op.owner, op.call) } }
        var copied: TransferReport? = null
        try {
            op.check()
            withContext(Dispatchers.IO) { service.transfer(Bundle().apply {
                putString("owner", op.owner); putString("call", op.call); putString("remotePath", spec.remotePath); putBoolean("toChannel", spec.toChannel)
                putLong("fileLimit", spec.fileLimitBytes); putLong("totalLimit", spec.totalLimitBytes); putInt("entryLimit", spec.entryLimit.toInt())
            }, pair[1], object : ICommandCallback.Stub() { override fun finished(value: Bundle) { result.complete(value) } }, client) }
            pair[1].close(); if (op.cancelled) op.stopAction()
            val report = withContext(Dispatchers.IO) { copy(spec, local, op, input, output) }
            copied = report
            val remote = withTimeout(15000) { result.await() }
            check(!remote.containsKey("error")) { "transferFailed" }
            return reportBundle(report)
        } catch (error: Exception) {
            val remoteError = withTimeoutOrNull(1500) { result.await().getString("error") }
            if (copied != null) throw TransferFault(remoteError ?: "transferFailed", copied)
            if (error is TransferFault && remoteError != null) throw TransferFault(remoteError, error.report)
            throw error
        } finally { runCatching { pair[1].close() }; op.close() }
    }
    private suspend fun termuxTransfer(spec: ChannelTransferSpec, local: File, op: Operation): Bundle {
        val server = ServerSocket(0, 4, InetAddress.getByName("127.0.0.1")); server.soTimeout = 1000
        op.resources += server
        val token = TermuxResults.token()
        op.stopAction = { op.close() }
        var request: TermuxRequest? = null
        var copied: TransferReport? = null
        try {
            op.check()
            request = withContext(Dispatchers.Main) { termux.dispatch(termux.executable, listOf("transfer", server.localPort.toString(), token,
                if (spec.toChannel) "receive" else "send", spec.remotePath, spec.fileLimitBytes.toString(), spec.totalLimitBytes.toString(), spec.entryLimit.toString())) }
            val deadline = SystemClock.elapsedRealtime() + 15000
            var socket: Socket? = null
            while (socket == null) {
                op.check(); check(SystemClock.elapsedRealtime() < deadline) { "transferTimeout" }
                if (request.result.isCompleted) { termux.await(request); error("transferDisconnected") }
                val candidate = try { withContext(Dispatchers.IO) { server.accept() } } catch (_: java.net.SocketTimeoutException) { continue }
                candidate.soTimeout = 1000
                val valid = runCatching {
                    val auth = ByteArray(64); DataInputStream(candidate.getInputStream()).readFully(auth)
                    MessageDigest.isEqual(auth, token.toByteArray(Charsets.US_ASCII))
                }.getOrDefault(false)
                if (valid) socket = candidate else candidate.close()
            }
            socket.soTimeout = 30000; op.resources += socket
            socket.getOutputStream().write(1)
            val report = withContext(Dispatchers.IO) { copy(spec, local, op, socket.getInputStream(), socket.getOutputStream()) }
            copied = report
            val remote = withTimeout(15000) { termux.await(request) }
            check(remote.getBoolean("ok"))
            return reportBundle(report)
        } catch (error: Exception) {
            val remoteError = try {
                withTimeoutOrNull(1500) { request?.let { termux.await(it) } }; null
            } catch (failure: CommandTransportFault) { failure.code } catch (_: Exception) { null }
            if (copied != null) throw TransferFault(remoteError ?: "transferFailed", copied)
            if (error is TransferFault && remoteError != null) throw TransferFault(remoteError, error.report)
            throw error
        } finally { op.close(); request?.close() }
    }
    override suspend fun cancel(ownerId: String, callId: String) {
        val op = active[callId] ?: return
        require(op.owner == ownerId)
        op.stop()
        if (withTimeoutOrNull(35000) { op.done.await(); true } != true) { op.lost.complete(Unit); op.close() }
    }
    override suspend fun endOwner(ownerId: String) {
        val owned = active.values.filter { it.owner == ownerId }
        owned.forEach { it.stop() }
        owned.forEach { if (withTimeoutOrNull(35000) { it.done.await(); true } != true) it.lost.complete(Unit); it.close() }
    }
    fun stopOwner(owner: String) { scope.launch { endOwner(owner) } }
    private fun stopChannel(channel: String, reason: String) {
        val affected = active.values.filter { it.channel == channel }
        affected.forEach { op -> scope.launch { op.stop(reason); op.close() } }
        affected.map { it.owner }.distinct().forEach { owner -> scope.launch(Dispatchers.Main) { runCatching { flutter.ownerStopped(owner) } } }
    }
}
