package app.xiangyue.phase.workspace

import java.io.File

/** Host paths only. Guest cwd never participates in host path authorization. */
object UbuntuFilesystemLayout {
    private val idPattern = Regex("[a-zA-Z0-9_-]{1,100}")
    fun rootfs(linuxRoot: File) = File(linuxRoot, "environments/ubuntu/rootfs")
    fun sessions(linuxRoot: File) = File(rootfs(linuxRoot), "sessions")

    fun managedRootfs(linuxRoot: File, path: String): File {
        val file = File(path).absoluteFile
        require(file.path == file.canonicalPath && file.isDirectory)
        val staging = File(linuxRoot, "staging")
        val installId = file.parentFile?.name ?: ""
        val staged = file.name == "rootfs" && idPattern.matches(installId) && file.parentFile?.parentFile == staging
        require(file == rootfs(linuxRoot) || staged)
        return file
    }

    private fun realDirectory(directory: File) = directory.isDirectory && directory.absolutePath == directory.canonicalPath
    private fun inSession(linuxRoot: File, file: File): Boolean {
        val base = sessions(linuxRoot)
        if (!realDirectory(base) || !file.path.startsWith(base.path + File.separator)) return false
        val id = file.relativeTo(base).path.substringBefore(File.separator)
        return idPattern.matches(id)
    }

    private fun inStagedWorkspace(linuxRoot: File, file: File): Boolean {
        val base = File(linuxRoot, "staging")
        if (!realDirectory(base) || !file.path.startsWith(base.path + File.separator)) return false
        return file.relativeTo(base).path.substringBefore(File.separator).startsWith("workspace-")
    }

    fun managedFile(linuxRoot: File, path: String): File {
        val file = File(path).canonicalFile
        require(inSession(linuxRoot, file) || inStagedWorkspace(linuxRoot, file))
        return file
    }

    fun managedTransferRoot(linuxRoot: File, path: String): File {
        val file = File(path).absoluteFile
        require(realDirectory(file) && (inSession(linuxRoot, file) || inStagedWorkspace(linuxRoot, file)))
        return file
    }
}
