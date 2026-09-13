package app.xiangyue.phase.execution

import app.xiangyue.phase.applications.ApplicationAccess
import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.bridge.*
import org.junit.Assert.*
import org.junit.Test
import kotlinx.coroutines.*

class ApplicationAccessTest {
    @Test fun cancellingReadOnlyDiscoveryDoesNotInventUnknownExternalEffects() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.LIST_APPS to NativeAction { _, _ -> entered.complete(Unit); awaitCancellation() })) {}
        tasks.begin("run")
        val result = async { tasks.execute(ExecutionRequest("run", "apps", ExecutionAction.LIST_APPS, emptyMap(), ExecutionTarget(), 10000)) }
        entered.await(); tasks.cancel("apps")
        assertEquals(ExecutionStatus.CANCELLED, result.await().status)
    }
    private fun black(blocked: List<String> = emptyList(), system: List<String> = emptyList()) =
        ApplicationPolicy(ApplicationListMode.BLACKLIST, blocked, emptyList(), system)
    private fun white(allowed: List<String>) = ApplicationPolicy(ApplicationListMode.WHITELIST, emptyList(), allowed, emptyList())

    @Test fun defaultsExcludeSystemButAllowExplicitSystemException() {
        assertTrue(ApplicationAccess.allows(black(), "third", false))
        assertFalse(ApplicationAccess.allows(black(), "system", true))
        assertTrue(ApplicationAccess.allows(black(system = listOf("system")), "system", true))
        assertFalse(ApplicationAccess.allows(black(listOf("system"), listOf("system")), "system", true))
        assertFalse(ApplicationAccess.allows(white(emptyList()), "third", false))
        assertTrue(ApplicationAccess.allows(white(listOf("system")), "system", true))
    }

    @Test fun bothDiscoveryAndDispatchUseTheSameLiveAndRunPolicyIntersection() {
        val snapshot = black(system = listOf("system"))
        val current = black(listOf("denied"), listOf("system"))
        val entries = listOf("allowed" to false, "denied" to false, "system" to true)
        val discovered = entries.filter { ApplicationAccess.allows(snapshot, current, it.first, it.second) }
        assertEquals(listOf("allowed", "system"), discovered.map { it.first })
        entries.forEach { (name, system) -> assertEquals(discovered.any { it.first == name }, ApplicationAccess.allows(snapshot, current, name, system)) }
        assertFalse(ApplicationAccess.allows(snapshot, white(emptyList()), "allowed", false))
        assertFalse(ApplicationAccess.allows(white(emptyList()), black(), "newlyAllowed", false))
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
