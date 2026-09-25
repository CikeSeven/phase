package app.xiangyue.phase.commands

import android.app.PendingIntent
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.*
import android.util.Base64
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import org.json.JSONObject

internal class CommandTransportFault(val code: String) : IOException(code)
internal data class TermuxReply(val stdout: String, val stderr: String, val exitCode: Int, val error: Int)
internal class TermuxRequest(val id: String, val intent: PendingIntent, val result: CompletableDeferred<TermuxReply>) : AutoCloseable {
    override fun close() { TermuxResults.pending.remove(id); intent.cancel(); result.cancel() }
}
internal object TermuxResults {
    val pending = ConcurrentHashMap<String, CompletableDeferred<TermuxReply>>()
    fun token(): String = ByteArray(32).also(SecureRandom()::nextBytes).joinToString("") { "%02x".format(it) }
}
class TermuxResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.data?.takeIf { it.scheme == "phase-termux" }?.lastPathSegment ?: return
        val pending = TermuxResults.pending.remove(id) ?: return
        try {
            val result = intent.getBundleExtra("result") ?: error("missingResult")
            val out = result.getString("stdout") ?: ""
            val err = result.getString("stderr") ?: ""
            check(out.length <= 65536 && err.length <= 8192)
            for ((name, value) in listOf("stdout" to out, "stderr" to err)) {
                if (result.containsKey("${name}_original_length")) check(result.getInt("${name}_original_length") == value.length)
            }
            check(result.containsKey("exitCode"))
            pending.complete(TermuxReply(out, err, result.getInt("exitCode"), if (result.containsKey("err")) result.getInt("err") else -1))
        } catch (_: Exception) { pending.completeExceptionally(IllegalStateException("invalidTermuxReply")) }
    }
}
internal class TermuxTransport(private val context: Context) {
    companion object {
        const val PACKAGE = "com.termux"
        const val PERMISSION = "com.termux.permission.RUN_COMMAND"
        const val HOME = "/data/data/com.termux/files/home"
        const val PREFIX = "/data/data/com.termux/files/usr"
        const val ROOT = "$HOME/.phase-commands"
        const val JOBS = "$ROOT/jobs"
    }
    val packaged get() = File(context.applicationInfo.nativeLibraryDir, "libphase_command.so")
    val revision: String by lazy { MessageDigest.getInstance("SHA-256").digest(packaged.readBytes()).joinToString("") { "%02x".format(it) } }
    val executable get() = "$ROOT/runner-$revision"
    fun installed() = runCatching { context.packageManager.getApplicationInfo(PACKAGE, 0) }.isSuccess
    fun uid() = context.packageManager.getApplicationInfo(PACKAGE, 0).uid
    fun permitted() = context.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED
    fun dispatch(program: String, args: List<String>, stdin: String = ""): TermuxRequest {
        check(permitted()) { "permissionRequired" }
        check(stdin.toByteArray().size <= 160 * 1024 && args.sumOf { it.toByteArray().size } <= 16384)
        val id = TermuxResults.token()
        val result = CompletableDeferred<TermuxReply>()
        check(TermuxResults.pending.putIfAbsent(id, result) == null)
        val callback = PendingIntent.getBroadcast(context, 0,
            Intent(context, TermuxResultReceiver::class.java).setData(Uri.parse("phase-termux://result/$id")),
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_MUTABLE)
        val request = TermuxRequest(id, callback, result)
        try {
            val command = Intent("com.termux.RUN_COMMAND").setComponent(ComponentName(PACKAGE, "com.termux.app.RunCommandService"))
                .putExtra("com.termux.RUN_COMMAND_PATH", program)
                .putExtra("com.termux.RUN_COMMAND_ARGUMENTS", args.toTypedArray())
                .putExtra("com.termux.RUN_COMMAND_STDIN", stdin)
                .putExtra("com.termux.RUN_COMMAND_WORKDIR", HOME)
                .putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                .putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", callback)
                .putExtra("com.termux.RUN_COMMAND_COMMAND_LABEL", "相月命令")
            check(context.startService(command) != null) { "termuxRejected" }
            return request
        } catch (error: Exception) { request.close(); throw error }
    }
    suspend fun await(request: TermuxRequest): JSONObject {
        val reply = request.result.await()
        check(reply.error == -1) { "termuxCommandFailed" }
        val json = JSONObject(reply.stdout)
        check(json.getInt("version") == 1) { "invalidTermuxReply" }
        if (!json.isNull("error")) throw CommandTransportFault(json.getString("error"))
        check(reply.exitCode == 0) { "termuxCommandFailed" }
        return json
    }
    suspend fun call(args: List<String>, stdin: String = "", program: String = executable): JSONObject {
        val request = withContext(Dispatchers.Main) { dispatch(program, args, stdin) }
        return try { withTimeout(15000) { await(request) } } finally { request.close() }
    }
    suspend fun probe(): JSONObject = call(listOf("probe")).also { check(it.getInt("uid") == uid()) { "identityChanged" } }
    suspend fun initialize() {
        check(packaged.isFile && Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a")
        // Bootstrap scripts are internal, never evaluated from model arguments. No package install or rc files.
        suspend fun script(text: String) = call(listOf("--noprofile", "--norc", "-s"), text, "$PREFIX/bin/bash")
        val temp = "$ROOT/.runner-${TermuxResults.token()}.part"
        script("set -eu\ncommand -v base64 >/dev/null\ncommand -v sha256sum >/dev/null\nmkdir -p '$ROOT' '$JOBS'\nchmod 700 '$ROOT' '$JOBS'\n[ ! -L '$ROOT' ] && [ ! -L '$JOBS' ]\n(umask 077; set -C; : > '$temp')\nprintf '{\"version\":1}'")
        try {
            packaged.inputStream().use { input ->
                val buffer = ByteArray(32768)
                while (true) {
                    currentCoroutineContext().ensureActive()
                    val count = input.read(buffer); if (count < 0) break
                    val encoded = Base64.encodeToString(buffer.copyOf(count), Base64.NO_WRAP)
                    script("set -eu\nprintf '%s' '$encoded' | base64 -d >> '$temp'\nprintf '{\"version\":1}'")
                }
            }
            script("set -eu\n[ \"\$(sha256sum '$temp' | cut -d ' ' -f 1)\" = '$revision' ]\nchmod 700 '$temp'\nmv '$temp' '$executable'\nprintf '{\"version\":1}'")
            probe()
        } finally {
            withContext(NonCancellable) { runCatching { script("rm -f '$temp'\nprintf '{\"version\":1}'") } }
        }
    }
}
