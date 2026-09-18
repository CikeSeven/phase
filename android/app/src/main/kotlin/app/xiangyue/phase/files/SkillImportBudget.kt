package app.xiangyue.phase.files

/** Limits are supplied by the Dart importer, and applied to actual copied bytes. */
class SkillImportBudget(private val maxEntries: Long, private val maxBytes: Long,
    private val maxFileBytes: Long, private val maxDepth: Long, private val maxPathLength: Long) {
    private var entries = 0L
    private var bytes = 0L
    private var fileBytes = 0L
    private val paths = mutableSetOf<String>()

    fun entry(path: String) {
        val parts = path.split('/')
        require(path.isNotEmpty() && path.length <= maxPathLength && parts.size <= maxDepth)
        require(parts.all { it.isNotEmpty() && it != "." && it != ".." })
        require(path.none { it.code < 32 || it.code == 127 || it == '\\' || it == ':' })
        require(paths.add(path))
        require(++entries <= maxEntries)
        fileBytes = 0
    }

    fun chunk(size: Int) {
        require(size >= 0)
        fileBytes += size
        bytes += size
        require(fileBytes <= maxFileBytes && bytes <= maxBytes)
    }
}
