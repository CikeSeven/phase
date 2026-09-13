package app.xiangyue.phase.fixture

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract as Docs
import android.provider.DocumentsProvider
import java.io.File

/** Real SAF provider containing only deterministic test documents in the fixture sandbox. */
class FixtureDocuments : DocumentsProvider() {
    private val root get() = File(context!!.filesDir, "documents").apply { mkdirs() }
    private val columns = arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME, Docs.Document.COLUMN_MIME_TYPE, Docs.Document.COLUMN_FLAGS, Docs.Document.COLUMN_SIZE)
    override fun onCreate(): Boolean { val note = File(root, "notes.txt"); if (!note.exists()) note.writeText("AI Agent 是可以调用工具并观察结果的助手。\n保存摘要之前需要用户确认。\n"); return true }
    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cols = projection ?: arrayOf(Docs.Root.COLUMN_ROOT_ID, Docs.Root.COLUMN_DOCUMENT_ID, Docs.Root.COLUMN_TITLE, Docs.Root.COLUMN_FLAGS, Docs.Root.COLUMN_MIME_TYPES)
        return MatrixCursor(cols).apply { val values = mapOf<String, Any?>(Docs.Root.COLUMN_ROOT_ID to "fixture", Docs.Root.COLUMN_DOCUMENT_ID to "root", Docs.Root.COLUMN_TITLE to "相月执行测试文件", Docs.Root.COLUMN_FLAGS to Docs.Root.FLAG_SUPPORTS_CREATE, Docs.Root.COLUMN_MIME_TYPES to "*/*"); addRow(cols.map { values[it] }.toTypedArray()) }
    }
    private fun file(id: String): File {
        if (id == "root") return root
        require(id.isNotEmpty() && id != "." && id != ".." && !id.contains('/') && !id.contains('\\'))
        return File(root, id)
    }
    private fun row(cursor: MatrixCursor, id: String) {
        val file = file(id)
        val values = mapOf<String, Any?>(Docs.Document.COLUMN_DOCUMENT_ID to id, Docs.Document.COLUMN_DISPLAY_NAME to if (id == "root") "测试目录" else id,
            Docs.Document.COLUMN_MIME_TYPE to if (id == "root") Docs.Document.MIME_TYPE_DIR else "text/plain",
            Docs.Document.COLUMN_SIZE to file.length(), Docs.Document.COLUMN_FLAGS to if (id == "root") Docs.Document.FLAG_DIR_SUPPORTS_CREATE else Docs.Document.FLAG_SUPPORTS_WRITE)
        cursor.addRow(cursor.columnNames.map { values[it] }.toTypedArray())
    }
    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor = MatrixCursor(projection ?: columns).also { row(it, documentId) }
    override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor = MatrixCursor(projection ?: columns).also { cursor -> require(parentDocumentId == "root"); root.listFiles()?.sortedBy { it.name }?.forEach { row(cursor, it.name) } }
    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor = ParcelFileDescriptor.open(file(documentId), ParcelFileDescriptor.parseMode(mode))
    override fun createDocument(parentDocumentId: String, mimeType: String, displayName: String): String { require(parentDocumentId == "root"); val target = file(displayName); check(target.createNewFile()); return displayName }
    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean = parentDocumentId == "root" && documentId != "root" && file(documentId).parentFile == root
}
