package app.xiangyue.phase.workspace

import app.xiangyue.phase.bridge.process.LinuxProcessSpec
import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class UbuntuFilesystemLayoutTest {
    @Test fun onlyFixedOrInstallerStagingRootsCanExecute() {
        val root = Files.createTempDirectory("phase-ufs").toFile().canonicalFile
        try {
            val installed = UbuntuFilesystemLayout.rootfs(root).apply { mkdirs() }
            val staged = File(root, "staging/install-fixture/rootfs").apply { mkdirs() }
            assertEquals(installed, UbuntuFilesystemLayout.managedRootfs(root, installed.path))
            assertEquals(staged, UbuntuFilesystemLayout.managedRootfs(root, staged.path))
            for (path in listOf("environments/old-revision", "staging/scratch", "sessions/a", "staging/a/nested/rootfs")) {
                val directory = File(root, path).apply { mkdirs() }
                assertThrows(IllegalArgumentException::class.java) { UbuntuFilesystemLayout.managedRootfs(root, directory.path) }
            }
            val alias = File(root, "staging/alias")
            Files.createSymbolicLink(alias.toPath(), installed.toPath())
            assertThrows(IllegalArgumentException::class.java) { UbuntuFilesystemLayout.managedRootfs(root, alias.path) }
        } finally { root.deleteRecursively() }
    }

    @Test fun exportsAndTermuxTransfersUseRealSessionOrTemporaryDirectories() {
        val root = Files.createTempDirectory("phase-ufs").toFile().canonicalFile
        try {
            val session = File(UbuntuFilesystemLayout.sessions(root), "a").apply { mkdirs() }
            val staged = File(root, "staging/workspace-fixture").apply { mkdirs() }
            for (directory in listOf(session, staged)) {
                val file = File(directory, "report").apply { writeText("fixture") }
                assertEquals(directory, UbuntuFilesystemLayout.managedTransferRoot(root, directory.path))
                assertEquals(file, UbuntuFilesystemLayout.managedFile(root, file.path))
            }
            for (path in listOf("workspaces/a", "environments/ubuntu/rootfs/root", "environments/ubuntu/rootfs/services/mcp/server", "staging/install-fixture")) {
                val directory = File(root, path).apply { mkdirs() }
                assertThrows(IllegalArgumentException::class.java) { UbuntuFilesystemLayout.managedTransferRoot(root, directory.path) }
            }
            val outside = File(root, "outside").apply { writeText("outside") }
            val link = File(session, "escape")
            Files.createSymbolicLink(link.toPath(), outside.toPath())
            assertThrows(IllegalArgumentException::class.java) { UbuntuFilesystemLayout.managedFile(root, link.path) }
        } finally { root.deleteRecursively() }
    }

    @Test fun shellAndMcpKeepRawArgvAndArbitraryGuestCwdWithoutWorkspaceBind() {
        for (cwd in listOf("/sessions/a", "/sessions/b", "/root", "/services/mcp/server", "/missing")) {
            val spec = LinuxProcessSpec("owner", "process", "/fixed/rootfs", "/bin/sh", listOf("-c", "cd /tmp && pwd"), cwd, emptyMap())
            val args = LinuxProcessHost.commandArguments(File("/libs"), File("/receipt"), File(spec.rootfs), spec)
            assertEquals(listOf("-b", "/dev", "-b", "/proc", "-w", cwd), args.subList(args.indexOf("-b"), args.indexOf("/usr/bin/env")))
            assertEquals(listOf("-i", "-C", cwd), args.subList(args.indexOf("/usr/bin/env") + 1, args.indexOf("/usr/bin/env") + 4))
            assertEquals(listOf("/bin/sh", "-c", "cd /tmp && pwd"), args.takeLast(3))
            assertFalse(args.any { it.contains("/workspace") || it.contains(":/sessions") })
        }
    }
}
