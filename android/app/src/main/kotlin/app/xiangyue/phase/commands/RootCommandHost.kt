package app.xiangyue.phase.commands

import android.content.Context
import android.os.Bundle
import app.xiangyue.phase.shizuku.ShizukuDeviceHost
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

class RootCommandHost(
    context: Context,
    messenger: BinaryMessenger,
    private val rootModeEnabled: () -> Boolean,
    private val shizuku: ShizukuDeviceHost,
) {
    private val runner = File(context.applicationInfo.nativeLibraryDir, "libphase_exec.so")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val appPackage = context.packageName
    private var running: RunningAction? = null

    init {
        MethodChannel(messenger, "app.xiangyue.phase/root_commands").setMethodCallHandler { call, reply ->
            when (call.method) {
                "execute" -> executeManual(call.arguments as? String, reply)
                "authorize" -> execute(listOf("/system/bin/id", "-u"), reply)
                "executeDeviceAction" -> executeDeviceAction(call.arguments as? Map<*, *>, reply)
                "executeAndroidShell" -> executeAndroidShell(call.arguments as? Map<*, *>, reply)
                "cancel" -> {
                    running?.takeIf { it.id == null }?.stop?.complete(Unit)
                    reply.success(null)
                }
                "cancelDeviceAction" -> {
                    running?.takeIf { it.id != null && (call.arguments == null || call.arguments == it.id) }
                        ?.stop?.complete(Unit)
                    reply.success(null)
                }
                else -> reply.notImplemented()
            }
        }
    }

    private fun executeManual(command: String?, reply: MethodChannel.Result) {
        if (command.isNullOrBlank() || '\u0000' in command ||
            command.toByteArray(Charsets.UTF_8).size > MAX_COMMAND_BYTES) {
            reply.error("invalidCommand", null, null)
            return
        }
        execute(listOf("/system/bin/sh", "-c", command), reply)
    }

    private fun executeDeviceAction(request: Map<*, *>?, reply: MethodChannel.Result) {
        if (!rootModeEnabled()) {
            reply.error("channelDisabled", null, null)
            return
        }
        val fields = request.orEmpty()
        val id = fields["id"] as? String
        val action = fields["action"] as? String
        val target = fields["packageName"] as? String
        val needsPackage = action in setOf("app_path", "launch_app", "force_stop_app")
        if (id == null || !ACTION_ID.matches(id) || fields.keys.any { it !is String || it !in ACTION_KEYS } ||
            (needsPackage && (target == null || target.length > 255 || !PACKAGE_NAME.matches(target))) ||
            (!needsPackage && fields.containsKey("packageName")) ||
            (action == "force_stop_app" && target == appPackage)) {
            reply.error("invalidAction", null, null)
            return
        }
        val argv = when (action) {
            "list_apps" -> listOf("/system/bin/pm", "list", "packages", "--user", "current")
            "app_path" -> listOf("/system/bin/pm", "path", "--user", "current", checkNotNull(target))
            "processes" -> listOf("/system/bin/ps", "-A", "-o", "PID,PPID,USER,NAME")
            "battery" -> listOf("/system/bin/dumpsys", "battery")
            "storage" -> listOf("/system/bin/df", "-h", "/data", "/sdcard")
            "launch_app" -> listOf("/system/bin/am", "start", "-W", "--user", "current",
                "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER",
                "-p", checkNotNull(target))
            "force_stop_app" -> listOf("/system/bin/am", "force-stop", "--user", "current", checkNotNull(target))
            else -> {
                reply.error("invalidAction", null, null)
                return
            }
        }
        execute(argv, reply, id)
    }

    private fun executeAndroidShell(request: Map<*, *>?, reply: MethodChannel.Result) {
        val id = request?.get("id") as? String
        val command = request?.get("command") as? String
        val uid = (request?.get("uid") as? Number)?.toLong()
        val argv = AndroidShellCommand.resolve(command)
        if (id == null || !ACTION_ID.matches(id) || argv == null || uid == null) {
            reply.error("unsupportedShellCommand", null, null)
            return
        }
        when (request?.get("channel")) {
            "root" -> {
                if (!rootModeEnabled() || uid != 0L) {
                    reply.error("channelDisabled", null, null)
                    return
                }
                execute(argv, reply, id)
            }
            "shizuku" -> {
                if (rootModeEnabled() || !shizuku.isEnabled()) {
                    reply.error("channelDisabled", null, null)
                    return
                }
                val arguments = Bundle().apply {
                    putString("id", id)
                    putString("command", command)
                    putLong("uid", uid)
                    putString("revision", request?.get("revision") as? String)
                }
                dispatch(id, reply) { stop ->
                    val result = shizuku.executeShell(arguments, stop)
                    result.getString("error")?.let { throw RootCommandFailure(it) }
                    mapOf(
                        "status" to result.getString("status"),
                        "exitCode" to result.getInt("exitCode").takeIf { result.containsKey("exitCode") },
                        "output" to result.getString("output"),
                        "truncated" to result.getBoolean("truncated"),
                    )
                }
            }
            else -> reply.error("channelDisabled", null, null)
        }
    }

    private fun execute(argv: List<String>, reply: MethodChannel.Result, id: String? = null) =
        dispatch(id, reply) { stop -> withContext(Dispatchers.IO) { runCommand(argv, stop) } }

    private fun dispatch(
        id: String?, reply: MethodChannel.Result, run: suspend (CompletableDeferred<Unit>) -> Map<String, Any?>,
    ) {
        if (running != null) {
            reply.error("busy", null, null)
            return
        }
        val action = RunningAction(id)
        running = action
        scope.launch {
            try {
                reply.success(run(action.stop))
            } catch (failure: RootCommandFailure) {
                reply.error(failure.code, null, null)
            } catch (_: IOException) {
                reply.error("executionFailed", null, null)
            } catch (_: SecurityException) {
                reply.error("executionFailed", null, null)
            } finally {
                running = null
            }
        }
    }

    private suspend fun runCommand(argv: List<String>, stop: CompletableDeferred<Unit>): Map<String, Any?> {
        if (!runner.canExecute()) throw RootCommandFailure("unsupported")
        val script = "cd / && exec ${shellQuote(runner.path)} --controlled-root ${argv.joinToString(" ") { shellQuote(it) }}"
        val child = try {
            ProcessBuilder("su", "-c", script).start()
        } catch (_: IOException) {
            throw RootCommandFailure("suUnavailable")
        }
        try {
            val protocol = ByteArrayOutputStream()
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var verified = false
            var sentStart = false
            var truncated = false

            fun drain() {
                readAvailable(child.inputStream, protocol, buffer, 64)
                if (!verified && protocol.size() >= ROOT_HANDSHAKE.length) {
                    verified = protocol.toString(Charsets.US_ASCII.name()).startsWith(ROOT_HANDSHAKE)
                    if (verified && !stop.isCompleted) {
                        child.outputStream.write('1'.code)
                        child.outputStream.flush()
                        sentStart = true
                    }
                }
                if (readAvailable(child.errorStream, output, buffer, MAX_OUTPUT_BYTES)) truncated = true
            }

            suspend fun waitForExit(stopWhenRequested: Boolean): Boolean {
                while (!stopWhenRequested || !stop.isCompleted) {
                    drain()
                    if (hasExited(child)) {
                        // Drain data buffered by the transport after the last poll.
                        repeat(16) {
                            if (child.inputStream.available() == 0 && child.errorStream.available() == 0) {
                                return true
                            }
                            drain()
                        }
                        truncated = truncated || child.errorStream.available() > 0
                        return true
                    }
                    delay(40)
                }
                return false
            }

            val completed = withTimeoutOrNull(EXECUTION_LIMIT_MS) { waitForExit(stopWhenRequested = true) } == true
            val interruption = when {
                completed -> null
                stop.isCompleted -> "cancelled"
                else -> "timedOut"
            }
            if (interruption != null) {
                stop.complete(Unit)
                if (sentStart) runCatching {
                    child.outputStream.write('0'.code)
                    child.outputStream.flush()
                }
                runCatching { child.outputStream.close() }
                withTimeoutOrNull(CLEANUP_LIMIT_MS) { waitForExit(stopWhenRequested = false) }
            }
            if (interruption == null && !verified) throw RootCommandFailure("permissionRequired")

            val report = protocol.toString(Charsets.US_ASCII.name()).removePrefix(ROOT_HANDSHAKE)
            val exitCode = EXIT_REPORT.find(report)?.groupValues?.get(1)?.toIntOrNull()
            val status = when {
                sentStart && exitCode == null && !report.startsWith("TIMEOUT\n") -> "unconfirmed"
                interruption != null -> interruption
                report.startsWith("TIMEOUT\n") -> "timedOut"
                exitCode != null -> "exited"
                else -> "unconfirmed"
            }
            return mapOf(
                "status" to status,
                "exitCode" to exitCode,
                "output" to if (sentStart) output.toString(Charsets.UTF_8.name()) else "",
                "truncated" to (sentStart && truncated),
            )
        } finally {
            runCatching { child.outputStream.close() }
            child.destroy()
        }
    }

    private fun hasExited(process: Process): Boolean = try {
        process.exitValue()
        true
    } catch (_: IllegalThreadStateException) {
        false
    }

    private fun readAvailable(
        source: InputStream,
        target: ByteArrayOutputStream,
        buffer: ByteArray,
        limit: Int,
    ): Boolean {
        var remaining = minOf(source.available(), buffer.size * 4)
        var truncated = false
        while (remaining > 0) {
            val count = source.read(buffer, 0, minOf(buffer.size, remaining))
            if (count <= 0) break
            val kept = minOf(count, limit - target.size())
            target.write(buffer, 0, kept)
            truncated = truncated || kept < count
            remaining -= count
        }
        return truncated
    }

    private fun shellQuote(value: String) = "'" + value.replace("'", "'\"'\"'") + "'"

    private class RunningAction(val id: String?, val stop: CompletableDeferred<Unit> = CompletableDeferred())
    private class RootCommandFailure(val code: String) : Exception()

    private companion object {
        const val ROOT_HANDSHAKE = "PHASROOT\n"
        val EXIT_REPORT = Regex("^EXIT:([0-9]{1,3})\n")
        val ACTION_ID = Regex("[a-zA-Z0-9_-]{1,100}")
        val PACKAGE_NAME = Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+")
        val ACTION_KEYS = setOf("id", "action", "packageName")
        const val MAX_COMMAND_BYTES = 16 * 1024
        const val MAX_OUTPUT_BYTES = 256 * 1024
        const val EXECUTION_LIMIT_MS = 60000L
        const val CLEANUP_LIMIT_MS = 3000L
    }
}
