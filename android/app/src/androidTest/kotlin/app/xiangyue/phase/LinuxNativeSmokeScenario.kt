package app.xiangyue.phase

import android.app.Instrumentation
import android.os.Bundle
import android.system.Os
import android.system.OsConstants
import app.xiangyue.phase.bridge.process.LinuxProcessSpec
import app.xiangyue.phase.workspace.LinuxProcessHost
import app.xiangyue.phase.workspace.UbuntuFilesystemLayout
import java.io.DataInputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Fresh, digest-checked staging fixture only. Never opens the business DB or installed rootfs. */
class LinuxNativeSmokeScenario(private val instrumentation: Instrumentation, private val archivePath: String) {
    fun run(report: Bundle) {
        check(archivePath.startsWith("/data/local/tmp/phase-ufs-"))
        val archive = File(archivePath)
        val digest = MessageDigest.getInstance("SHA-256")
        archive.inputStream().use { input ->
            val bytes = ByteArray(65536)
            while (true) { val count = input.read(bytes); if (count < 0) break; digest.update(bytes, 0, count) }
        }
        check(digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) } == "a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2")
        val context = instrumentation.targetContext
        val linux = File(context.noBackupFilesDir, "linux").canonicalFile
        val root = File(linux, "staging/native-smoke-${UUID.randomUUID()}").apply { mkdirs() }
        val rootfs = File(root, "rootfs").apply { mkdirs() }
        val pool = Executors.newFixedThreadPool(2)
        val libs = File(context.applicationInfo.nativeLibraryDir)
        try {
            val extraction = ProcessBuilder("/system/bin/toybox", "tar", "-xzf", archive.path, "-C", rootfs.path).redirectErrorStream(true).start()
            val extractionOutput = extraction.inputStream.bufferedReader().readText()
            check(extraction.waitFor(15, TimeUnit.SECONDS) && extraction.exitValue() == 0) { extractionOutput }
            check(File(rootfs, "usr/bin/sh").exists())
            for (directory in listOf("tmp", "root", "dev", "proc", "sessions/a", "sessions/b", "services/mcp/server")) File(rootfs, directory).mkdirs()
            val a = File(rootfs, "sessions/a")
            val b = File(rootfs, "sessions/b")
            File(a, "before-command").writeText("already-in-rootfs")
            check(UbuntuFilesystemLayout.managedRootfs(linux, rootfs.path) == rootfs)
            val nativeTemporary = File(root, "proot-tmp").apply { mkdirs() }

            fun start(command: String, cwd: String = "/sessions/a"): Pair<Process, Int> {
                val result = File(root, "exit-${System.nanoTime()}")
                val spec = LinuxProcessSpec("native-smoke", "process-${System.nanoTime()}", rootfs.path, "/bin/sh", listOf("-c", command), cwd, emptyMap())
                val args = LinuxProcessHost.commandArguments(libs, result, rootfs, spec)
                check(args.none { it.contains(":/workspace") || it.contains(":/sessions") })
                val builder = ProcessBuilder(args).directory(rootfs)
                builder.environment().apply {
                    clear(); put("PROOT_LOADER", File(libs, "libphase_loader.so").path)
                    put("LD_LIBRARY_PATH", libs.path); put("PROOT_NO_SECCOMP", "1")
                    put("TMPDIR", nativeTemporary.path); put("PROOT_TMP_DIR", nativeTemporary.path)
                }
                val process = builder.start()
                val header = ByteArray(8)
                DataInputStream(process.inputStream).readFully(header)
                val words = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                check(words.int == 0x50484153)
                return Pair(process, words.int)
            }
            fun command(command: String, cwd: String = "/sessions/a"): Triple<Int, String, String> {
                val (process, _) = start(command, cwd)
                val stdout = pool.submit<String> { process.inputStream.bufferedReader().readText() }
                val stderr = pool.submit<String> { process.errorStream.bufferedReader().readText() }
                process.outputStream.close()
                check(process.waitFor(10, TimeUnit.SECONDS))
                return Triple(process.exitValue(), stdout.get(2, TimeUnit.SECONDS), stderr.get(2, TimeUnit.SECONDS))
            }
            check(command("pwd") == Triple(0, "/sessions/a\n", ""))
            check(command("cat before-command") == Triple(0, "already-in-rootfs", ""))
            check(command("pwd", "/sessions/b") == Triple(0, "/sessions/b\n", ""))
            check(command("printf shared > shared.txt; printf global > /root/shared.txt; cd /tmp; export TRANSIENT=1; pwd") == Triple(0, "/tmp\n", ""))
            check(command("printf '%s\\n' \"\${TRANSIENT-unset}\"; pwd") == Triple(0, "unset\n/sessions/a\n", ""))
            check(command("cat /sessions/a/shared.txt /root/shared.txt", "/sessions/b") == Triple(0, "sharedglobal", ""))
            check(command("pwd", "/root") == Triple(0, "/root\n", ""))
            check(command("pwd", "/services/mcp/server") == Triple(0, "/services/mcp/server\n", ""))
            for (cwd in listOf("/missing", "/root/shared.txt")) {
                val result = command("touch /sessions/a/should-not-run", cwd)
                check(result.first != 0 && result.third.isNotEmpty())
                check(!File(a, "should-not-run").exists() && !File(rootfs, "missing").exists())
            }
            check(b.listFiles()!!.isEmpty())

            val (process, _) = start("read value; printf '%s' \"\$value\" > result; printf stdout; printf stderr >&2; exit 23")
            val stdout = pool.submit<String> { process.inputStream.bufferedReader().readText() }
            val stderr = pool.submit<String> { process.errorStream.bufferedReader().readText() }
            process.outputStream.write("phase-ready\n".toByteArray()); process.outputStream.close()
            check(process.waitFor(10, TimeUnit.SECONDS))
            check(process.exitValue() == 23 && stdout.get(2, TimeUnit.SECONDS) == "stdout" && stderr.get(2, TimeUnit.SECONDS) == "stderr")
            check(File(a, "result").readText() == "phase-ready")
            val (idle, pid) = start("sleep 60 & echo \$! > child; wait")
            val idleOut = pool.submit<String> { idle.inputStream.bufferedReader().readText() }
            val idleErr = pool.submit<String> { idle.errorStream.bufferedReader().readText() }
            for (attempt in 0 until 100) { if (File(a, "child").exists()) break; Thread.sleep(10) }
            check(File(a, "child").exists())
            val child = File(a, "child").readText().trim().toInt()
            Os.kill(pid, OsConstants.SIGTERM)
            check(idle.waitFor(5, TimeUnit.SECONDS))
            idleOut.get(2, TimeUnit.SECONDS); idleErr.get(2, TimeUnit.SECONDS)
            check(!File("/proc/$child").exists())
            report.putString("phase_result", "passed: real rootfs session files, shared global/cross-session access, independent cwd/env, explicit and invalid cwd, service cwd, raw pipes, nonzero exit and child cancellation")
            report.putString("fixture_scope", "fresh staging rootfs; installed rootfs and business DB untouched")
            report.putString("native_dir", libs.path)
        } finally {
            pool.shutdownNow()
            root.deleteRecursively()
        }
    }
}
