package app.xiangyue.phase.workspace

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.system.Os
import android.system.OsConstants
import app.xiangyue.phase.bridge.process.*
import app.xiangyue.phase.execution.ExecutionService
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Runtime handles only. Dart owns persisted runs and all tool policy decisions. */
class LinuxProcessHost(private val context: Context, private val flutter: LinuxProcessFlutterApi) : LinuxProcessHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val owners = ConcurrentHashMap<String, CompletableDeferred<Unit>>()
    private val tasks = ConcurrentHashMap<String, Running>()
    private val seen = ConcurrentHashMap.newKeySet<String>()
    private var service: ExecutionService? = null
    private val root = File(context.noBackupFilesDir, "linux").canonicalFile.apply { mkdirs() }
    private val nativeDir = File(context.applicationInfo.nativeLibraryDir)
    private val idPattern = Regex("[a-zA-Z0-9_-]{1,100}")

    override fun platformInfo() = LinuxPlatformInfo(root.path, Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown",
        Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a" && File(nativeDir, "libphase_proot.so").canExecute() && File(nativeDir, "libphase_loader.so").canExecute(), root.usableSpace)

    override suspend fun setModes(paths: List<String>, modes: List<Long>) = withContext(Dispatchers.IO) {
        require(paths.size == modes.size && paths.size <= 256)
        val base = File(root, "staging").canonicalPath + File.separator
        paths.zip(modes).forEach { (path, mode) ->
            val file = File(path)
            require(file.canonicalPath.startsWith(base) && file.canonicalPath == file.absolutePath && mode in 0..511)
            Os.chmod(path, mode.toInt())
        }
    }
    override suspend fun beginTask(ownerId: String, label: String) {
        require(idPattern.matches(ownerId))
        val notifications = context.getSystemService(NotificationManager::class.java)
        check(notifications.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || notifications.getNotificationChannel(ExecutionService.CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE)) { "notificationsRequired" }
        val ready = CompletableDeferred<Unit>()
        val existing = owners.putIfAbsent(ownerId, ready)
        if (existing != null) { existing.await(); return }
        try {
            withContext(Dispatchers.Main) {
                val intent = Intent(context, ExecutionService::class.java)
                    .putExtra(ExecutionService.PROCESS_OWNER, ownerId)
                    .putExtra(ExecutionService.TASK_LABEL, label.take(80))
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            }
            withTimeout(5000) { ready.await() }
        } catch (error: Exception) {
            owners.remove(ownerId, ready)
            ready.completeExceptionally(error)
            throw IllegalStateException("processHostUnavailable")
        }
    }
    fun expectsStart(id: String) = owners.containsKey(id)
    fun serviceStarted(host: ExecutionService, id: String) {
        service = host
        owners[id]?.complete(Unit)
    }
    fun serviceFailed(id: String) { owners[id]?.completeExceptionally(IllegalStateException("processHostUnavailable")) }
    fun serviceStopped(host: ExecutionService) {
        if (service !== host) return
        service = null
        owners.keys.toList().forEach(::stopFromSystem)
    }
    fun stopFromSystem(ownerId: String) {
        owners.remove(ownerId)?.completeExceptionally(IllegalStateException("cancelled"))
        tasks.values.filter { it.spec.ownerId == ownerId }.forEach { it.terminate(cancelled = true) }
        scope.launch(Dispatchers.Main) { flutter.taskStopped(ownerId) }
        scope.launch { endTask(ownerId) }
    }
    override suspend fun endTask(ownerId: String) {
        owners.remove(ownerId)
        val owned = tasks.values.filter { it.spec.ownerId == ownerId }
        owned.forEach { it.terminate(cancelled = true) }
        owned.forEach { it.done.await() }
        withContext(Dispatchers.Main) { service?.finishProcess(ownerId) }
    }
    private fun managedPath(path: String, section: String): File {
        val file = File(path).canonicalFile
        val base = File(root, section).canonicalFile
        require(file.path.startsWith(base.path + File.separator) && file.isDirectory)
        return file
    }
    override suspend fun start(spec: LinuxProcessSpec) {
        require(owners[spec.ownerId]?.isCompleted == true && idPattern.matches(spec.processId))
        require(platformInfo().available)
        // Only installer staging and installed environments can become a guest root.
        val rootfs = try { managedPath(spec.rootfs, "environments") } catch (_: IllegalArgumentException) { managedPath(spec.rootfs, "staging") }
        val workspace = try { managedPath(spec.workspace, "workspaces") } catch (_: IllegalArgumentException) { managedPath(spec.workspace, "staging") }
        require(spec.executable.startsWith("/") && spec.cwd.startsWith("/") && !spec.executable.contains('\u0000'))
        require(spec.timeoutMs == null || spec.timeoutMs!! in 1..300000)
        require(spec.outputLimitBytes == null || spec.outputLimitBytes!! in 1..(64L * 1024 * 1024))
        require(spec.argv.size <= 128 && spec.argv.sumOf { it.length } <= 131072 && spec.argv.none { it.contains('\u0000') })
        require(spec.environment.size <= 64 && spec.environment.all { (key, value) -> key.matches(Regex("[A-Za-z_][A-Za-z0-9_]*")) && !value.contains('\u0000') && value.length <= 32768 })
        require(seen.add(spec.processId)) { "processIdAlreadyUsed" }
        val running = Running(spec, rootfs, workspace)
        tasks[spec.processId] = running
        scope.launch { running.run() }
    }
    private fun owned(owner: String, id: String): Running = tasks[id]?.takeIf { it.spec.ownerId == owner } ?: throw IllegalStateException("processUnavailable")
    override suspend fun writeStdin(ownerId: String, processId: String, bytes: ByteArray) {
        require(bytes.size <= 65536)
        owned(ownerId, processId).write(bytes)
    }
    override suspend fun closeStdin(ownerId: String, processId: String) {
        val running = tasks[processId] ?: return
        require(running.spec.ownerId == ownerId)
        running.closeInput()
    }
    override suspend fun cancel(ownerId: String, processId: String) {
        val running = tasks[processId] ?: return
        require(running.spec.ownerId == ownerId)
        running.terminate(cancelled = true)
        running.done.await()
    }

    private inner class Running(val spec: LinuxProcessSpec, val rootfs: File, val workspace: File) {
        val done = CompletableDeferred<Unit>()
        private val inputMutex = Mutex()
        private val eventMutex = Mutex()
        private val started = CompletableDeferred<Unit>()
        @Volatile private var process: Process? = null
        @Volatile private var pid = 0
        @Volatile private var cancelled = false
        @Volatile private var timedOut = false
        @Volatile private var limited = false
        @Volatile private var terminating = false
        private var sequence = 0L
        private var received = 0L
        private val outputLimit = spec.outputLimitBytes ?: Long.MAX_VALUE
        private var error: String? = null
        private val resultFile = File(File(root, "processes").apply { mkdirs() }, spec.processId)
        private val temporary = File(resultFile.parentFile, "tmp-${spec.processId}").apply { mkdirs() }

        fun terminate(cancelled: Boolean = false, timeout: Boolean = false) {
            synchronized(this) {
                this.cancelled = this.cancelled || cancelled
                timedOut = timedOut || timeout
                terminating = true
                if (pid > 0) try { Os.kill(pid, OsConstants.SIGTERM) } catch (_: Exception) { }
            }
            // The supervisor sends TERM, then KILL, and reaps the entire group.
        }
        suspend fun write(bytes: ByteArray) {
            started.await()
            inputMutex.withLock {
                check(!terminating && !done.isCompleted)
                withContext(Dispatchers.IO) { process!!.outputStream.write(bytes); process!!.outputStream.flush() }
            }
        }
        suspend fun closeInput() {
            started.await()
            inputMutex.withLock { withContext(Dispatchers.IO) { process!!.outputStream.close() } }
        }
        suspend fun emit(kind: LinuxEventKind, bytes: ByteArray? = null, code: Long? = null, signal: Long? = null) {
            eventMutex.withLock {
                val event = LinuxProcessEvent(spec.ownerId, spec.processId, sequence++, kind, bytes, code, signal, error, cancelled, timedOut, limited)
                withContext(Dispatchers.Main) {
                    withTimeout(10000) {
                        flutter.event(event)
                    }
                }
            }
        }
        suspend fun pump(input: java.io.InputStream, kind: LinuxEventKind) {
            try {
                val buffer = ByteArray(16384)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    val accepted = synchronized(this) {
                        val size = minOf(count.toLong(), (outputLimit - received).coerceAtLeast(0)).toInt()
                        received += size
                        if (size < count || received == outputLimit) limited = true
                        size
                    }
                    if (accepted > 0) emit(kind, buffer.copyOf(accepted))
                    if (limited) terminate()
                }
            } catch (_: Exception) { error = "outputReadFailed"; terminate() }
        }
        suspend fun run() {
            var timeout: Job? = null
            var exitCode: Long? = null
            var signal: Long? = null
            try {
                if (terminating) return
                val args = listOf(File(nativeDir, "libphase_exec.so").path, resultFile.path,
                    File(nativeDir, "libphase_proot.so").path, "--kill-on-exit", "-0", "-r", rootfs.path,
                    "-b", "/dev", "-b", "/proc", "-b", "${workspace.path}:/workspace", "-w", spec.cwd,
                    "/usr/bin/env", "-i", "HOME=/root", "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG=C.UTF-8", "TMPDIR=/tmp") +
                    spec.environment.map { (key, value) -> "$key=$value" } + listOf(spec.executable) + spec.argv
                val builder = ProcessBuilder(args).directory(rootfs)
                builder.environment().apply {
                    clear()
                    put("PROOT_LOADER", File(nativeDir, "libphase_loader.so").path)
                    put("PROOT_NO_SECCOMP", "1")
                    put("LD_LIBRARY_PATH", nativeDir.path)
                    put("TMPDIR", temporary.path)
                    put("PROOT_TMP_DIR", temporary.path)
                }
                val child = builder.start()
                process = child
                timeout = spec.timeoutMs?.let { milliseconds -> scope.launch { delay(milliseconds); terminate(timeout = true) } }
                val header = ByteArray(8)
                java.io.DataInputStream(child.inputStream).readFully(header)
                val words = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                check(words.int == 0x50484153)
                synchronized(this) { pid = words.int; if (terminating) terminate() }
                started.complete(Unit)
                emit(LinuxEventKind.STARTED)
                coroutineScope {
                    val out = launch(Dispatchers.IO) { pump(child.inputStream, LinuxEventKind.STDOUT) }
                    val err = launch(Dispatchers.IO) { pump(child.errorStream, LinuxEventKind.STDERR) }
                    exitCode = withContext(Dispatchers.IO) { child.waitFor().toLong() }
                    out.join(); err.join()
                }
                val status = if (resultFile.isFile) resultFile.readText().trim().split(' ').map(String::toLong) else emptyList()
                if (status.size == 2) { exitCode = status[0].takeIf { it >= 0 }; signal = status[1].takeIf { it > 0 } }
            } catch (_: Exception) {
                error = "processFailed"
                terminate()
                process?.waitFor()
            } finally {
                timeout?.cancel()
                started.completeExceptionally(IllegalStateException("processExited"))
                process?.let { p ->
                    try { p.outputStream.close() } catch (_: Exception) { }
                    try { p.inputStream.close() } catch (_: Exception) { }
                    try { p.errorStream.close() } catch (_: Exception) { }
                }
                resultFile.delete()
                temporary.deleteRecursively()
                try { emit(LinuxEventKind.EXITED, code = exitCode, signal = signal) } catch (_: Exception) { }
                tasks.remove(spec.processId, this)
                done.complete(Unit)
            }
        }
    }
}
