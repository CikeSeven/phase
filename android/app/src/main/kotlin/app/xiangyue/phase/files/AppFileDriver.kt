package app.xiangyue.phase.files

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import android.provider.DocumentsContract as Docs
import app.xiangyue.phase.bridge.*
import java.io.Closeable
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** SAF authorization is checked against both the frozen run scope and live persisted grants. */
class AppFileDriver(private val context: Context) {
    private val resolver = context.contentResolver
    private val workers = Executors.newFixedThreadPool(2)
    private val cache get() = File(context.cacheDir, "execution_files").apply { mkdirs() }
    private data class Metadata(val name: String, val size: Long, val mime: String)

    suspend fun grants(): List<FileGrant> = io { _, _ ->
        resolver.persistedUriPermissions.filter { it.isReadPermission }.map { grant ->
            val uri = grant.uri
            try {
                val info = metadata(document(uri))
                FileGrant(uri.toString(), info.name, Docs.isTreeUri(uri), grant.isWritePermission)
            } catch (_: Exception) {
                FileGrant(uri.toString(), "已失效的文件授权（可解除）", Docs.isTreeUri(uri), false)
            }
        }
    }

    fun release(uri: String) {
        val grant = resolver.persistedUriPermissions.firstOrNull { it.uri.toString() == uri } ?: return
        resolver.releasePersistableUriPermission(grant.uri,
            (if (grant.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
            (if (grant.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0))
    }

    suspend fun execute(request: ExecutionRequest, roots: List<String>): ExecutionResult = io { signal, active ->
        var affected = false
        var actual: Uri? = null
        try {
            val raw = request.target.uri ?: throw IllegalArgumentException("uri")
            val root = authorized(raw, roots, request.action == ExecutionAction.WRITE_FILE)
            val output = when (request.action) {
                ExecutionAction.LIST_FILES -> {
                    require(Docs.isTreeUri(root))
                    val offset = (request.arguments["offset"] as? Number)?.toInt() ?: 0
                    val limit = (request.arguments["limit"] as? Number)?.toInt() ?: 100
                    require(offset >= 0 && limit in 1..200)
                    val children = children(root, signal).sortedBy { it["name"] as String }
                    val page = mutableListOf<Map<String, Any?>>()
                    var pageBytes = 0
                    for (child in children.drop(offset).take(limit)) {
                        val size = (child["path"].toString() + child["name"].toString()).toByteArray(Charsets.UTF_8).size
                        if (page.isNotEmpty() && pageBytes + size > 16 * 1024) break
                        page.add(child)
                        pageBytes += size
                    }
                    val result = mutableMapOf<String, Any?>("path" to raw, "files" to page, "total" to children.size)
                    if (offset + page.size < children.size) result["nextOffset"] = offset + page.size
                    ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, result, emptyList())
                }
                ExecutionAction.READ_FILE -> {
                    val file = copy(document(root), signal, active)
                    ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, details(file), listOf(file))
                }
                ExecutionAction.WRITE_FILE -> {
                    val bytes = (request.arguments["content"] as? String ?: throw IllegalArgumentException("content")).toByteArray(Charsets.UTF_8)
                    require(bytes.size <= 128 * 1024)
                    val directory = request.arguments["directory"] as? String
                    var parent = document(root)
                    val name: String
                    val existing: Uri?
                    if (directory != null) {
                        require(Docs.isTreeUri(root))
                        val segments = relativeSegments(request.arguments["path"] as? String ?: "")
                        for (segment in segments.dropLast(1)) {
                            signal.throwIfCanceled()
                            val found = find(parent, segment, signal)
                            parent = if (found != null) {
                                require(metadata(found).mime == Docs.Document.MIME_TYPE_DIR)
                                found
                            } else {
                                affected = true
                                val created = Docs.createDocument(resolver, parent, Docs.Document.MIME_TYPE_DIR, segment)
                                    ?: throw IllegalStateException("mkdir")
                                actual = created
                                val actualName = metadata(created).name
                                if (actualName != segment) throw DocumentNameException(actualName)
                                created
                            }
                        }
                        name = segments.last()
                        existing = find(parent, name, signal)
                    } else {
                        existing = document(root)
                        val meta = metadata(existing)
                        require(meta.mime != Docs.Document.MIME_TYPE_DIR)
                        name = meta.name
                    }
                    if (existing != null) require(metadata(existing).mime != Docs.Document.MIME_TYPE_DIR)
                    // edit_file reads and matches in Dart; this guards the read/write interval.
                    val expected = request.arguments["expectedSha256"] as? String
                    if (expected != null && (existing == null || expected != digest(existing, signal, active))) {
                        return@io failure(request, ChannelError.TARGET_CHANGED, "文件在编辑期间已变化，请重新读取后编辑")
                    }
                    signal.throwIfCanceled()
                    affected = true
                    val destination = existing ?: createExactDocument(name,
                        create = { mime, displayName -> Docs.createDocument(resolver, parent, mime, displayName)
                            ?: throw IllegalStateException("create") },
                        nameOf = { metadata(it).name },
                        onCreated = { actual = it })
                    actual = destination
                    signal.throwIfCanceled()
                    resolver.openOutputStream(destination, "wt")?.use { stream ->
                        active.set(stream); signal.throwIfCanceled()
                        stream.write(bytes); stream.flush()
                    } ?: throw IllegalStateException("open")
                    active.set(null)
                    val file = copy(destination, signal, active)
                    if (file.name != name || file.sha256 != hash(bytes)) {
                        File(file.localPath!!).delete()
                        return@io ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                            mapOf("uri" to actual.toString(), "reason" to "写入后的校验不一致"), emptyList(), ChannelError.EXECUTION_FAILED)
                    }
                    ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, details(file), listOf(file))
                }
                else -> failure(request, ChannelError.INVALID_ARGUMENTS, "不是文件动作")
            }
            output
        } catch (error: DocumentNameException) {
            ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                mapOf("uri" to actual?.toString(), "name" to error.actualName,
                    "reason" to "文件提供器更改了名称，已创建空文件或目录但未写入内容"), emptyList(), ChannelError.EXECUTION_FAILED)
        } catch (_: SecurityException) {
            if (affected) writeFailure(request, actual) else failure(request, ChannelError.PERMISSION_REQUIRED, "文件授权已失效，请重新选择文件或目录")
        } catch (_: IllegalArgumentException) {
            if (affected) writeFailure(request, actual) else failure(request, ChannelError.INVALID_ARGUMENTS, "文件引用、名称或参数无效")
        } catch (_: Exception) {
            if (affected) writeFailure(request, actual) else failure(request, ChannelError.EXECUTION_FAILED, "文件读取失败或超过 20MB 上限")
        }
    }

    private fun authorized(raw: String, roots: List<String>, write: Boolean): Uri {
        val uri = Uri.parse(raw)
        if (uri.scheme != "content") throw SecurityException()
        val target = document(uri)
        val allowed = resolver.persistedUriPermissions.any { permission ->
            val root = permission.uri
            permission.isReadPermission && (!write || permission.isWritePermission) && root.toString() in roots &&
                (uri == root || (Docs.isTreeUri(root) && root.authority == uri.authority &&
                    (document(root) == target || Docs.isChildDocument(resolver, document(root), target))))
        }
        if (!allowed) throw SecurityException()
        return uri
    }

    private fun document(uri: Uri): Uri = if (Docs.isTreeUri(uri) && !Docs.isDocumentUri(context, uri))
        Docs.buildDocumentUriUsingTree(uri, Docs.getTreeDocumentId(uri)) else uri

    private fun children(uri: Uri, signal: CancellationSignal): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        val childUri = Docs.buildChildDocumentsUriUsingTree(uri, Docs.getDocumentId(document(uri)))
        resolver.query(childUri, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME, Docs.Document.COLUMN_MIME_TYPE, Docs.Document.COLUMN_SIZE), null, null, null, signal)?.use { cursor ->
            while (cursor.moveToNext()) {
                signal.throwIfCanceled()
                result.add(mapOf("path" to Docs.buildDocumentUriUsingTree(uri, cursor.getString(0)).toString(),
                    "name" to cursor.getString(1), "directory" to (cursor.getString(2) == Docs.Document.MIME_TYPE_DIR), "size" to cursor.getLong(3)))
            }
        } ?: throw IllegalStateException("query")
        return result
    }

    private fun find(uri: Uri, name: String, signal: CancellationSignal): Uri? {
        // Query all names for an exact match; listing limits must not hide an existing overwrite target.
        val query = Docs.buildChildDocumentsUriUsingTree(uri, Docs.getDocumentId(document(uri)))
        resolver.query(query, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME), null, null, null, signal)?.use { cursor ->
            while (cursor.moveToNext()) {
                signal.throwIfCanceled()
                if (cursor.getString(1) == name) return Docs.buildDocumentUriUsingTree(uri, cursor.getString(0))
            }
        } ?: throw IllegalStateException("query")
        return null
    }

    private fun metadata(uri: Uri): Metadata = resolver.query(uri, arrayOf(Docs.Document.COLUMN_DISPLAY_NAME, Docs.Document.COLUMN_SIZE, Docs.Document.COLUMN_MIME_TYPE), null, null, null)?.use {
        if (!it.moveToFirst()) throw IllegalArgumentException("missing")
        Metadata(it.getString(0), it.getLong(1), it.getString(2))
    } ?: throw IllegalArgumentException("missing")

    private fun copy(uri: Uri, signal: CancellationSignal, active: AtomicReference<Closeable?>): ExecutionArtifact {
        val meta = metadata(uri)
        require(meta.mime != Docs.Document.MIME_TYPE_DIR && meta.size <= MAX_BYTES)
        val file = File(cache, UUID.randomUUID().toString())
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            var size = 0L
            resolver.openInputStream(uri)?.use { input ->
                active.set(input)
                file.outputStream().use { output ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        signal.throwIfCanceled()
                        val count = input.read(buffer)
                        if (count < 0) break
                        size += count; require(size <= MAX_BYTES)
                        digest.update(buffer, 0, count); output.write(buffer, 0, count)
                    }
                }
            } ?: throw IllegalStateException("read")
            active.set(null)
            return ExecutionArtifact(uri.toString(), meta.name, size, hex(digest.digest()), file.path)
        } catch (error: Exception) { file.delete(); throw error }
    }

    private fun digest(uri: Uri, signal: CancellationSignal, active: AtomicReference<Closeable?>): String {
        val copied = copy(uri, signal, active)
        File(copied.localPath!!).delete()
        return copied.sha256!!
    }

    private suspend fun <T> io(block: (CancellationSignal, AtomicReference<Closeable?>) -> T): T = suspendCancellableCoroutine { continuation ->
        val signal = CancellationSignal()
        val active = AtomicReference<Closeable?>()
        val future = workers.submit {
            try { val value = block(signal, active); if (continuation.isActive) continuation.resume(value) }
            catch (error: Exception) { if (continuation.isActive) continuation.resumeWithException(error) }
            finally { try { active.getAndSet(null)?.close() } catch (_: Exception) {} }
        }
        continuation.invokeOnCancellation {
            signal.cancel(); future.cancel(true)
            try { active.getAndSet(null)?.close() } catch (_: Exception) {}
        }
    }

    companion object {
        const val MAX_BYTES = 20L * 1024 * 1024
        fun safeName(name: String): String {
            require(name.isNotBlank() && name != "." && name != ".." && name.toByteArray(Charsets.UTF_8).size <= 255 && name.none { it == '/' || it == '\\' || it == '\u0000' })
            return name
        }
        fun relativeSegments(path: String): List<String> {
            require(!path.startsWith('/') && !path.endsWith('/'))
            return path.split('/').filter { it != "." }.also { segments ->
                require(segments.isNotEmpty())
                segments.forEach { safeName(it) }
            }
        }
        fun hash(bytes: ByteArray) = hex(MessageDigest.getInstance("SHA-256").digest(bytes))
        private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
        private fun details(file: ExecutionArtifact) = mapOf<String, Any?>("uri" to file.uri, "name" to file.name, "size" to file.size, "sha256" to file.sha256)
        private fun failure(request: ExecutionRequest, error: ChannelError, message: String) = ExecutionResult(request.toolCallId, ExecutionStatus.FAILED, mapOf("reason" to message), emptyList(), error)
        private fun writeFailure(request: ExecutionRequest, uri: Uri?) = ExecutionResult(request.toolCallId, ExecutionStatus.FAILED, mapOf("uri" to uri?.toString(), "reason" to "文件写入未完成；需要时先读取目标内容，不要直接重复写入"), emptyList(), ChannelError.EXECUTION_FAILED)
    }
}
