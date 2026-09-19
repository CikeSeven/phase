package app.xiangyue.phase.files

class DocumentNameException(val actualName: String) : Exception("Document provider changed the requested name")

/** A MIME type with a preferred extension lets SAF silently rename README or script.py. */
internal fun <T> createExactDocument(
    name: String,
    create: (String, String) -> T,
    nameOf: (T) -> String,
    onCreated: (T) -> Unit,
): T {
    val document = create("application/octet-stream", name)
    onCreated(document)
    val actual = nameOf(document)
    if (actual != name) throw DocumentNameException(actual)
    return document
}
