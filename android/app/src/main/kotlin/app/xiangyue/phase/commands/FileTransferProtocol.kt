package app.xiangyue.phase.commands

import android.system.Os
import android.system.OsConstants
import java.io.*
import java.security.MessageDigest

internal data class TransferLimits(val file: Long, val total: Long, val entries: Int)
internal data class TransferReport(val paths: List<String>, val bytes: Long)
internal class TransferFault(val code: String, val report: TransferReport) : IOException(code)

/** Bounded manifest followed by file bytes/SHA-256, then explicit commit and receipt.
 * Both peers use big-endian integers and strict UTF-8. No network-supplied absolute paths. */
internal object FileTransferProtocol {
    private data class Entry(val path: String, val directory: Boolean, val size: Long)
    fun copy(
        input: InputStream, output: OutputStream, root: File, sending: Boolean,
        limits: TransferLimits, check: () -> Unit,
        progress: (Long) -> Unit = {},
    ): TransferReport {
        val reader = DataInputStream(BufferedInputStream(input, 32768))
        val writer = DataOutputStream(BufferedOutputStream(output, 32768))
        val entries = mutableListOf<Entry>()
        val temporary = mutableListOf<File>()
        val completed = mutableListOf<String>()
        var bytes = 0L
        var committing = false
        var succeeded = false
        val createdDirectories = mutableListOf<File>()
        fun ensureDirectory(file: File) {
            noLinks(file, true)
            if (file.exists()) { require(file.isDirectory) { "typeConflict" }; return }
            file.parentFile?.let { ensureDirectory(it) }
            require(file.mkdir()) { "directoryFailed" }
            createdDirectories += file
        }
        try {
            noLinks(root, !sending)
            if (sending) {
                scan(root, "", entries, limits)
                require(entries.sumOf { it.path.toByteArray(Charsets.UTF_8).size + 13 } <= 65536) { "transferLimit" }
                writer.writeInt(entries.size)
                entries.forEach { entry ->
                    writer.writeByte(if (entry.directory) 2 else 1)
                    val path = entry.path.toByteArray(Charsets.UTF_8)
                    require(path.size <= 4096) { "invalidPath" }
                    writer.writeInt(path.size); writer.write(path); writer.writeLong(entry.size)
                }
                writer.flush()
            } else {
                val count = reader.readInt()
                require(count in 1..limits.entries) { "transferLimit" }
                repeat(count) { index ->
                    val type = reader.readUnsignedByte()
                    val length = reader.readInt()
                    require(length in 0..4096) { "invalidPath" }
                    val raw = ByteArray(length).also(reader::readFully)
                    val path = Charsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(raw)).toString()
                    val size = reader.readLong()
                    require(type in 1..2 && validRelative(path) && (if (index == 0) path.isEmpty() else path.isNotEmpty()) &&
                        entries.none { it.path == path } && size in 0..limits.file && (type != 2 || size == 0L)) { "invalidManifest" }
                    if (index > 0) {
                        val parent = path.substringBeforeLast('/', "")
                        require(entries.any { it.path == parent && it.directory }) { "invalidManifest" }
                    }
                    entries += Entry(path, type == 2, size)
                    require(entries.sumOf { it.size } <= limits.total && entries.sumOf { it.path.toByteArray(Charsets.UTF_8).size + 13 } <= 65536) { "transferLimit" }
                }
                entries.forEach { entry ->
                    val target = child(root, entry.path)
                    noLinks(target, true)
                    if (target.exists()) require(if (entry.directory) target.isDirectory else target.isFile) { "typeConflict" }
                }
            }
            val buffer = ByteArray(32768)
            entries.filterNot { it.directory }.forEach { entry ->
                check()
                val path = child(root, entry.path)
                val digest = MessageDigest.getInstance("SHA-256")
                if (sending) {
                    noLinks(path, false)
                    val before = Os.stat(path.path)
                    require(before.st_size == entry.size && OsConstants.S_ISREG(before.st_mode)) { "sourceChanged" }
                    FileInputStream(path).use { file ->
                        var left = entry.size
                        while (left > 0) {
                            check()
                            val count = file.read(buffer, 0, minOf(left, buffer.size.toLong()).toInt())
                            require(count > 0) { "sourceChanged" }
                            writer.write(buffer, 0, count); digest.update(buffer, 0, count)
                            left -= count; bytes += count; progress(bytes)
                        }
                        require(file.read() == -1) { "sourceChanged" }
                    }
                    val after = Os.stat(path.path)
                    require(before.st_size == after.st_size && before.st_mtime == after.st_mtime && before.st_ino == after.st_ino) { "sourceChanged" }
                    writer.write(digest.digest()); writer.flush()
                } else {
                    ensureDirectory(path.parentFile!!)
                    val temp = File.createTempFile(".phase-transfer-", ".part", path.parentFile)
                    temporary += temp
                    FileOutputStream(temp).use { file ->
                        var left = entry.size
                        while (left > 0) {
                            check()
                            val count = minOf(left, buffer.size.toLong()).toInt()
                            reader.readFully(buffer, 0, count); file.write(buffer, 0, count); digest.update(buffer, 0, count)
                            left -= count; bytes += count; progress(bytes)
                        }
                        val expected = ByteArray(32).also(reader::readFully)
                        require(MessageDigest.isEqual(expected, digest.digest())) { "integrityFailed" }
                        file.fd.sync()
                    }
                }
            }
            check()
            if (sending) {
                require(reader.readUnsignedByte() == 1) { "transferRejected" }
                check(); writer.writeByte(1); writer.flush()
                val committed = reader.readUnsignedByte()
                val count = reader.readInt()
                require(count in 0..entries.size) { "invalidManifest" }
                completed += entries.take(count).map { it.path }
                require(committed == 1 && count == entries.size) { "commitFailed" }
            } else {
                writer.writeByte(1); writer.flush()
                require(reader.readUnsignedByte() == 1) { "transferCancelled" }
                committing = true
                var fileIndex = 0
                entries.forEach { entry ->
                    check()
                    val target = child(root, entry.path)
                    noLinks(target, true)
                    if (entry.directory) ensureDirectory(target) else {
                        require(!target.exists() || target.isFile) { "typeConflict" }
                        Os.rename(temporary[fileIndex++].path, target.path)
                    }
                    completed += entry.path
                }
                writer.writeByte(1); writer.writeInt(completed.size); writer.flush()
            }
            succeeded = true
            return TransferReport(completed, bytes)
        } catch (error: Exception) {
            if (!sending && committing) runCatching { writer.writeByte(0); writer.writeInt(completed.size); writer.flush() }
            val code = when (error) {
                is TransferFault -> error.code
                is IllegalArgumentException -> error.message?.takeIf { it in knownErrors } ?: "transferFailed"
                is java.util.concurrent.CancellationException -> "cancelled"
                is java.net.SocketTimeoutException -> "transferTimeout"
                else -> when (val cause = generateSequence<Throwable>(error) { it.cause }.filterIsInstance<android.system.ErrnoException>().firstOrNull()) {
                    null -> if (error is EOFException) "transferDisconnected" else "transferFailed"
                    else -> when (cause.errno) {
                        OsConstants.EACCES, OsConstants.EPERM -> "filePermissionDenied"
                        OsConstants.ENOSPC, OsConstants.EDQUOT -> "spaceUnavailable"
                        OsConstants.EROFS -> "readOnlyFileSystem"
                        OsConstants.ENOENT -> "fileMissing"
                        OsConstants.ENOTDIR -> "notDirectory"
                        else -> "transferFailed"
                    }
                }
            }
            throw TransferFault(code, TransferReport(completed.toList(), bytes))
        } finally {
            // Committed files have already moved; never remove destination files on failure.
            temporary.forEach { if (it.exists()) it.delete() }
            if (!succeeded) {
                val committed = completed.map { child(root, it).path }.toSet()
                createdDirectories.asReversed().filter { it.path !in committed }.forEach { it.delete() }
            }
        }
    }
    private val knownErrors = setOf("invalidPath", "symbolicLink", "typeConflict", "sourceChanged", "transferLimit", "invalidManifest", "unsupportedFile", "integrityFailed", "directoryFailed", "fileUnavailable", "commitFailed", "transferRejected", "transferCancelled")
    private fun validRelative(path: String) = path.isEmpty() || (!path.startsWith('/') && '\u0000' !in path && '\\' !in path && path.split('/').none { it.isEmpty() || it == "." || it == ".." })
    private fun child(root: File, path: String) = if (path.isEmpty()) root else File(root, path)
    private fun scan(root: File, path: String, result: MutableList<Entry>, limits: TransferLimits) {
        val file = child(root, path)
        val stat = Os.lstat(file.path)
        require(OsConstants.S_ISDIR(stat.st_mode) || OsConstants.S_ISREG(stat.st_mode)) { "unsupportedFile" }
        val directory = OsConstants.S_ISDIR(stat.st_mode)
        val size = if (directory) 0 else stat.st_size
        require(size in 0..limits.file && result.size < limits.entries && result.sumOf { it.size } + size <= limits.total) { "transferLimit" }
        require(path.toByteArray(Charsets.UTF_8).size <= 4096) { "invalidPath" }
        result += Entry(path, directory, size)
        if (directory) (file.listFiles() ?: throw IOException("directoryFailed")).sortedBy { it.name }.forEach {
            scan(root, if (path.isEmpty()) it.name else "$path/${it.name}", result, limits)
        }
    }
    fun noLinks(file: File, missing: Boolean) {
        require(file.isAbsolute && file.path.split('/').none { it == ".." || it == "." } && '\u0000' !in file.path) { "invalidPath" }
        var current: File? = file
        while (current != null) {
            try { require(!OsConstants.S_ISLNK(Os.lstat(current.path).st_mode)) { "symbolicLink" } }
            catch (error: android.system.ErrnoException) { if (!(missing && error.errno == OsConstants.ENOENT)) throw error }
            current = current.parentFile
        }
    }
}
