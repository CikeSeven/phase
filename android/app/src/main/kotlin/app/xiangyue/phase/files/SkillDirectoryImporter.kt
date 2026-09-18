package app.xiangyue.phase.files

import android.content.Context
import android.net.Uri
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract as Docs
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.Closeable
import java.io.File
import java.util.concurrent.atomic.AtomicReference

/** SAF contents are copied to an app cache directory; no persistent tool grant is added. */
class SkillDirectoryImporter(private val context: Context) {
    private var id: String? = null
    private var signal = CancellationSignal()
    private val active = AtomicReference<Closeable?>()

    fun begin(value: String) {
        require(value.matches(Regex("[a-zA-Z0-9-]{1,80}")))
        id = value
        signal = CancellationSignal()
    }
    fun cancel(value: String) {
        if (id != value) return
        signal.cancel()
        try { active.getAndSet(null)?.close() } catch (_: Exception) { }
    }
    fun finish(value: String) { if (id == value) { active.set(null); id = null } }

    suspend fun copy(uri: Uri, request: SkillDirectoryImport): SkillDirectoryCopy = withContext(Dispatchers.IO) {
        val cache = File(context.cacheDir, "skill_imports")
        val destination = File(cache, request.id)
        try {
            signal.throwIfCanceled()
            // Only one import exists at a time. Leftovers can only be interrupted copies.
            if (cache.exists() && !cache.deleteRecursively()) throw java.io.IOException()
            if (!destination.mkdirs()) throw java.io.IOException()
            val budget = SkillImportBudget(request.maxEntries, request.maxBytes, request.maxFileBytes,
                request.maxDepth, request.maxPathLength)
            val rootId = Docs.getTreeDocumentId(uri)
            val visited = mutableSetOf(rootId)
            val resolver = context.contentResolver
            fun walk(documentId: String, prefix: String) {
                signal.throwIfCanceled()
                val children = Docs.buildChildDocumentsUriUsingTree(uri, documentId)
                resolver.query(children, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID,
                    Docs.Document.COLUMN_DISPLAY_NAME, Docs.Document.COLUMN_MIME_TYPE), null, null, null, signal)?.use { cursor ->
                    while (cursor.moveToNext()) {
                        signal.throwIfCanceled()
                        val childId = cursor.getString(0)
                        val name = cursor.getString(1)
                        require(name.isNotEmpty() && !name.contains('/'))
                        val relative = if (prefix.isEmpty()) name else "$prefix/$name"
                        budget.entry(relative)
                        require(visited.add(childId))
                        val output = File(destination, relative)
                        if (cursor.getString(2) == Docs.Document.MIME_TYPE_DIR) {
                            if (!output.mkdirs()) throw java.io.IOException()
                            walk(childId, relative)
                        } else {
                            val child = Docs.buildDocumentUriUsingTree(uri, childId)
                            val fd = resolver.openFileDescriptor(child, "r", signal) ?: throw java.io.IOException()
                            ParcelFileDescriptor.AutoCloseInputStream(fd).use { input ->
                                active.set(input)
                                try {
                                    output.outputStream().use { sink ->
                                        val buffer = ByteArray(32768)
                                        while (true) {
                                            signal.throwIfCanceled()
                                            val length = input.read(buffer)
                                            if (length < 0) break
                                            budget.chunk(length)
                                            sink.write(buffer, 0, length)
                                        }
                                    }
                                } finally { active.compareAndSet(input, null) }
                            }
                        }
                    }
                } ?: throw java.io.IOException()
            }
            walk(rootId, "")
            signal.throwIfCanceled()
            val root = Docs.buildDocumentUriUsingTree(uri, rootId)
            val name = resolver.query(root, arrayOf(Docs.Document.COLUMN_DISPLAY_NAME), null, null, null, signal)?.use {
                if (it.moveToFirst()) it.getString(0) else "Skill"
            } ?: "Skill"
            SkillDirectoryCopy(destination.path, name)
        } catch (error: Exception) {
            if (destination.exists() && !destination.deleteRecursively()) {
                throw FlutterError("cleanupFailed", "目录导入未完成，临时副本清理失败，请重试", null)
            }
            if (signal.isCanceled || error is OperationCanceledException) {
                throw FlutterError("cancelled", "已取消目录导入", null)
            }
            when (error) {
                is IllegalArgumentException -> throw FlutterError("invalidDirectory", "目录含无效或重复路径，或超过 Skill 导入上限", null)
                is SecurityException -> throw FlutterError("permissionRequired", "没有读取所选目录的权限", null)
                else -> throw FlutterError("fileAccess", "无法复制目录文件，请检查文件访问权限和可用空间", null)
            }
        }
    }
}
