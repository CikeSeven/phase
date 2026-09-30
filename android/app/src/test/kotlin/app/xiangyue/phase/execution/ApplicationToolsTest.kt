package app.xiangyue.phase.execution

import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.bridge.*
import org.junit.Assert.*
import org.junit.Test
import kotlinx.coroutines.*

class ApplicationToolsTest {
    @Test fun cancellingReadOnlyDiscoveryDoesNotInventUnknownExternalEffects() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.LIST_APPS to NativeAction { _, _ -> entered.complete(Unit); awaitCancellation() })) {}
        tasks.begin("run")
        val result = async { tasks.execute(ExecutionRequest("run", "apps", ExecutionAction.LIST_APPS, emptyMap(), ExecutionTarget(), 10000)) }
        entered.await(); tasks.cancel("apps")
        assertEquals(ExecutionStatus.CANCELLED, result.await().status)
    }
    @Test fun metadataSortsAreDeterministicAndUnknownSizeIsLast() {
        fun app(id: String, installed: Long, bytes: Long?) = InstalledApplication(id, id, false, installed, true, "1", bytes)
        val list = listOf(app("b", 30, 10), app("a", 20, 90), app("c", 10, null))
        assertEquals(listOf("a", "b", "c"), ApplicationCatalog.sorted(list, "name").map { it.packageName })
        assertEquals(listOf("b", "a", "c"), ApplicationCatalog.sorted(list, "installedAt").map { it.packageName })
        assertEquals(listOf("a", "b", "c"), ApplicationCatalog.sorted(list, "size").map { it.packageName })
        assertFalse(ApplicationCatalog.details(list[0]).containsKey("sourceDir"))
        assertEquals("apk", ApplicationCatalog.details(list[0])["sizeKind"])
    }
}
