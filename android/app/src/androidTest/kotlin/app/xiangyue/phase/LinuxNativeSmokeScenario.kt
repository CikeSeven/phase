package app.xiangyue.phase

import android.app.Instrumentation
import android.os.Bundle
import android.system.Os
import android.system.OsConstants
import java.io.DataInputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Uses only staged fixtures and nativeLibraryDir. Never starts Dart or opens the business DB. */
class LinuxNativeSmokeScenario(private val instrumentation: Instrumentation) {
    fun run(report: Bundle) {
        val context = instrumentation.targetContext
        val root = File(context.noBackupFilesDir, "e3-native-fixture")
        val rootfs = File(root, "rootfs")
        val workspace = File(root, "workspace").apply { mkdirs() }
        val libs = File(context.applicationInfo.nativeLibraryDir)
        check(File(rootfs, "usr/bin/sh").exists())
        val pool = Executors.newFixedThreadPool(2)
        fun start(command: String): Pair<Process, Int> {
            val result = File(root, "exit-${System.nanoTime()}")
            val args = listOf(File(libs, "libphase_exec.so").path, result.path, File(libs, "libphase_proot.so").path,
                "--kill-on-exit", "-0", "-r", rootfs.path, "-b", "/dev", "-b", "/proc", "-b", "${workspace.path}:/workspace", "-w", "/workspace",
                "/usr/bin/env", "-i", "HOME=/root", "PATH=/usr/bin:/bin", "LANG=C.UTF-8", "/bin/sh", "-c", command)
            val builder = ProcessBuilder(args).directory(rootfs)
            builder.environment().apply { clear(); put("PROOT_LOADER", File(libs, "libphase_loader.so").path); put("LD_LIBRARY_PATH", libs.path); put("PROOT_NO_SECCOMP", "1"); put("TMPDIR", File(rootfs, "tmp").path); put("PROOT_TMP_DIR", File(rootfs, "tmp").path) }
            val process = builder.start()
            val header = ByteArray(8)
            DataInputStream(process.inputStream).readFully(header)
            val words = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
            check(words.int == 0x50484153)
            return Pair(process, words.int)
        }
        try {
            val startMs = System.currentTimeMillis()
            val (process, _) = start("read value; printf '%s' \"\$value\" > /workspace/result; printf stdout; printf stderr >&2; exit 23")
            val stdout = pool.submit<String> { process.inputStream.bufferedReader().readText() }
            val stderr = pool.submit<String> { process.errorStream.bufferedReader().readText() }
            process.outputStream.write("phase-ready\n".toByteArray()); process.outputStream.close()
            check(process.waitFor(10, TimeUnit.SECONDS))
            val out = stdout.get(2, TimeUnit.SECONDS)
            val err = stderr.get(2, TimeUnit.SECONDS)
            report.putString("native_output", "$out | $err")
            report.putInt("exit_code", process.exitValue())
            check(process.exitValue() == 23 && out == "stdout" && err == "stderr")
            check(File(workspace, "result").readText() == "phase-ready")
            report.putLong("command_ms", System.currentTimeMillis() - startMs)
            val (idle, pid) = start("sleep 60 & echo \$! > /workspace/child; wait")
            val idleOut = pool.submit<String> { idle.inputStream.bufferedReader().readText() }
            val idleErr = pool.submit<String> { idle.errorStream.bufferedReader().readText() }
            repeat(100) { if (!File(workspace, "child").exists()) Thread.sleep(10) }
            check(File(workspace, "child").exists())
            val child = File(workspace, "child").readText().trim().toInt()
            Os.kill(pid, OsConstants.SIGTERM)
            check(idle.waitFor(5, TimeUnit.SECONDS))
            idleOut.get(2, TimeUnit.SECONDS); idleErr.get(2, TimeUnit.SECONDS)
            check(!File("/proc/$child").exists())
            report.putString("phase_result", "passed: nativeLibraryDir exec, Ubuntu shell, stdin/stdout/stderr, file, exit 23 and child cancellation")
            report.putString("native_dir", libs.path)
            report.putInt("target_sdk", context.applicationInfo.targetSdkVersion)
        } finally { pool.shutdownNow() }
    }
}
