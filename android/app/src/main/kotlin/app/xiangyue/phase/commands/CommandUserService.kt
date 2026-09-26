package app.xiangyue.phase.commands

import android.content.Context
import android.os.*
import android.system.Os
import java.io.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.*
import org.json.JSONObject

/** Runs under the authorized Shizuku UID. Binder threads never perform command or transfer IO. */
@androidx.annotation.Keep
class CommandUserService(private val context: Context) : ICommandUserService.Stub() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private class Task(val owner: String, val cancel: AtomicBoolean, val close: () -> Unit, var closeOnCancel: Boolean = false)
    private val tasks = ConcurrentHashMap<String, Task>()
    private val seen = ConcurrentHashMap.newKeySet<String>()
    private val runner get() = File(context.applicationInfo.nativeLibraryDir, "libphase_command.so")
    override fun probe() = Bundle().apply {
        putInt("uid", Process.myUid())
        putBoolean("available", runner.canExecute() && Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a")
    }
    private fun own(spec: Bundle, close: () -> Unit): Task {
        check(Binder.getCallingUid() == context.applicationInfo.uid)
        check(spec.getLong("uid", -1) == Process.myUid().toLong()) { "identityChanged" }
        val id = spec.getString("call")!!
        check(id.matches(Regex("[a-zA-Z0-9_-]{1,100}")) && seen.add(id))
        val owner = spec.getString("owner")!!
        check(owner.matches(Regex("[a-zA-Z0-9_-]{1,100}")))
        return Task(owner, AtomicBoolean(false), close).also { tasks[id] = it }
    }
    override fun start(spec: Bundle, stdout: ParcelFileDescriptor, stderr: ParcelFileDescriptor, callback: ICommandCallback, client: IBinder) {
        val out = ParcelFileDescriptor.AutoCloseOutputStream(stdout)
        val err = ParcelFileDescriptor.AutoCloseOutputStream(stderr)
        val task = try {
            own(spec) { runCatching { out.close() }; runCatching { err.close() } }
        } catch (error: Exception) {
            runCatching { out.close() }; runCatching { err.close() }
            throw error
        }
        val id = spec.getString("call")!!
        // Keep ownership separate when Shizuku restarts under a different UID.
        val root = File("/data/local/tmp/phase-${context.packageName}-${Process.myUid()}")
        val job = File(root, id)
        val death = IBinder.DeathRecipient { task.cancel.set(true); task.close() }
        try { client.linkToDeath(death, 0) }
        catch (error: Exception) { tasks.remove(id, task); task.close(); throw error }
        scope.launch {
            var result = Bundle()
            try {
                FileTransferProtocol.noLinks(root, true)
                check(root.isDirectory || root.mkdir())
                Os.chmod(root.path, 0x1c0)
                check(job.mkdir())
                Os.chmod(job.path, 0x1c0)
                val values = mapOf("command" to spec.getString("command")!!, "cwd" to spec.getString("cwd")!!,
                    "shell" to "/system/bin/sh", "home" to "/", "path" to "/system/bin:/system/xbin",
                    "limit" to spec.getLong("limit").toString(), "lease" to (SystemClock.elapsedRealtime() + 30000).toString(), "token" to spec.getString("token")!!)
                values.forEach { (name, value) -> File(job, name).writeText(value); Os.chmod(File(job, name).path, 0x180) }
                if (task.cancel.get()) throw CancellationException()
                val process = ProcessBuilder(runner.path, "run", root.path, id, spec.getString("token")!!).apply {
                    environment().clear(); environment()["PATH"] = "/system/bin"
                }.start()
                process.outputStream.close()
                // The runner prints only its bounded terminal envelope; command streams are private log files.
                val terminal = async { process.inputStream.use { it.readBytesBounded(8192) } }
                val errors = async { process.errorStream.use { it.readBytesBounded(8192) } }
                val offsets = longArrayOf(0, 0)
                var renewal = 0L
                while (process.isAlive) {
                    if (task.cancel.get()) File(job, "cancel").writeText("1")
                    if (SystemClock.elapsedRealtime() - renewal > 5000) {
                        if (!task.cancel.get()) atomicText(File(job, "lease"), (SystemClock.elapsedRealtime() + 30000).toString())
                        renewal = SystemClock.elapsedRealtime()
                    }
                    drain(job, offsets, out, err)
                    delay(100)
                }
                process.waitFor(); terminal.await(); errors.await()
                drain(job, offsets, out, err)
                result = jsonResult(JSONObject(File(job, "result").readText()))
            } catch (_: Exception) {
                val cancelled = task.cancel.get()
                task.cancel.set(true)
                runCatching { if (job.isDirectory) File(job, "cancel").writeText("1") }
                result.putString("error", "channelDisconnected")
                result.putBoolean("cancelled", cancelled)
            } finally {
                task.close(); runCatching { client.unlinkToDeath(death, 0) }
                tasks.remove(id)
                // Only delete a settled job; a still-running supervisor needs its lease/cancel files.
                if (File(job, "result").isFile) job.deleteRecursively()
                runCatching { callback.finished(result) }
            }
        }
    }
    private fun drain(job: File, offsets: LongArray, out: OutputStream, err: OutputStream) {
        for ((index, name) in listOf("stdout", "stderr").withIndex()) {
            val file = File(job, name)
            if (!file.isFile) continue
            RandomAccessFile(file, "r").use { input ->
                input.seek(offsets[index]); val buffer = ByteArray(16384)
                while (true) { val count = input.read(buffer); if (count < 0) break
                    (if (index == 0) out else err).write(buffer, 0, count); offsets[index] += count }
            }
        }
    }
    override fun transfer(spec: Bundle, socket: ParcelFileDescriptor, callback: ICommandCallback, client: IBinder) {
        val input = ParcelFileDescriptor.AutoCloseInputStream(socket)
        val output = ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(socket.fileDescriptor))
        val task = try {
            own(spec) { runCatching { input.close() }; runCatching { output.close() } }.also { it.closeOnCancel = true }
        } catch (error: Exception) {
            runCatching { input.close() }; runCatching { output.close() }
            throw error
        }
        val id = spec.getString("call")!!
        val death = IBinder.DeathRecipient { task.cancel.set(true); task.close() }
        try { client.linkToDeath(death, 0) }
        catch (error: Exception) { tasks.remove(id, task); task.close(); throw error }
        scope.launch {
            val result = Bundle()
            try {
                val report = FileTransferProtocol.copy(input, output, File(spec.getString("remotePath")!!), !spec.getBoolean("toChannel"),
                    TransferLimits(spec.getLong("fileLimit"), spec.getLong("totalLimit"), spec.getInt("entryLimit")),
                    { if (task.cancel.get()) throw CancellationException() })
                result.putInt("completedCount", report.paths.size); result.putLong("bytes", report.bytes)
                result.putBoolean("terminationAcknowledged", true)
            } catch (error: Exception) {
                result.putString("error", (error as? TransferFault)?.code ?: "transferFailed")
                if (error is TransferFault) { result.putInt("completedCount", error.report.paths.size); result.putLong("bytes", error.report.bytes) }
                result.putBoolean("cancelled", task.cancel.get())
            } finally {
                task.close(); tasks.remove(id); runCatching { client.unlinkToDeath(death, 0) }
                runCatching { callback.finished(result) }
            }
        }
    }
    override fun cancel(owner: String, call: String) {
        tasks[call]?.let { check(it.owner == owner); it.cancel.set(true); if (it.closeOnCancel) it.close() }
    }
    override fun destroy() {
        tasks.values.forEach { it.cancel.set(true); it.close() }
        scope.launch { delay(32000); scope.cancel(); kotlin.system.exitProcess(0) }
    }
    companion object {
        internal fun jsonResult(json: JSONObject) = Bundle().apply {
            if (!json.isNull("exitCode")) putInt("exitCode", json.getInt("exitCode"))
            if (!json.isNull("signal")) putInt("signal", json.getInt("signal"))
            for (key in listOf("cancelled", "outputLimitExceeded", "terminationAcknowledged")) putBoolean(key, json.optBoolean(key))
            if (!json.isNull("error")) putString("error", json.getString("error"))
        }
        private fun atomicText(file: File, text: String) {
            val temp = File(file.parentFile, "${file.name}.service.tmp")
            temp.writeText(text); Os.rename(temp.path, file.path)
        }
        private fun InputStream.readBytesBounded(limit: Int): ByteArray {
            val output = ByteArrayOutputStream(); val buffer = ByteArray(1024)
            while (true) { val n = read(buffer); if (n < 0) break; check(output.size() + n <= limit); output.write(buffer, 0, n) }
            return output.toByteArray()
        }
    }
}
