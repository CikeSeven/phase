package app.xiangyue.phase.files

import org.junit.Assert.*
import org.junit.Test

class ExactDocumentCreationTest {
    @Test fun preservesRequestedNamesWithAProviderThatInfersExtensionsFromMime() {
        for (name in listOf("README", ".env", "script.py", "摘要.md", "data.json", "notes.txt")) {
            val calls = mutableListOf<Pair<String, String>>()
            var created: String? = null
            val actual = createExactDocument(name,
                create = { mime, requested ->
                    calls.add(mime to requested)
                    if (mime == "text/plain" && !requested.endsWith(".txt")) "$requested.txt" else requested
                },
                nameOf = { it }, onCreated = { created = it })
            assertEquals(name, actual)
            assertEquals(name, created)
            assertEquals(1, calls.size)
        }
    }

    @Test fun reportsProviderRenamingBeforeAnyContentWriteWithoutCreatingAgain() {
        var creates = 0
        var writes = 0
        var created: String? = null
        val error = assertThrows(DocumentNameException::class.java) {
            createExactDocument("README", create = { _, _ -> creates++; "README (1)" },
                nameOf = { it }, onCreated = { created = it })
            writes++
        }
        assertEquals("README (1)", error.actualName)
        assertEquals("README (1)", created)
        assertEquals(1, creates)
        assertEquals(0, writes)
    }

    @Test fun relativePathsKeepExactNamesAndRejectEscapesBeforeCreatingDirectories() {
        assertEquals(listOf("src", ".env"), AppFileDriver.relativeSegments("./src/.env"))
        for (path in listOf("../README", "a/../README", "/README", "a//README", "a/", "a\\README")) {
            assertThrows(IllegalArgumentException::class.java) { AppFileDriver.relativeSegments(path) }
        }
        assertEquals("月".repeat(80) + ".md", AppFileDriver.safeName("月".repeat(80) + ".md"))
        assertThrows(IllegalArgumentException::class.java) { AppFileDriver.safeName("月".repeat(86)) }
    }
}
