package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.*
import org.junit.Assert.*
import org.junit.Test

class UiTargetTest {
    private fun capture() = ExecutionRequest("run", "capture", ExecutionAction.CAPTURE_SCREEN,
        emptyMap(), ExecutionTarget(), 10000)

    @Test fun screenshotResolvesTheLiveForegroundOnEveryCall() {
        var foreground = "app.fixture.first"
        assertEquals(foreground, resolveUiTarget(capture()) { foreground })
        foreground = "app.fixture.next"
        assertEquals(foreground, resolveUiTarget(capture()) { foreground })
        assertNull(resolveUiTarget(capture()) { null })
        assertNull(resolveUiTarget(capture()) { "" })
    }

    @Test fun screenshotDoesNotAcceptPackageOverridesOrCachedSnapshotTargets() {
        for (request in listOf(
            capture().copy(arguments = mapOf("packageName" to "app.fixture.fake")),
            capture().copy(target = ExecutionTarget(packageName = "app.fixture.fake")),
            capture().copy(target = ExecutionTarget(snapshotId = "old")),
        )) {
            assertThrows(IllegalArgumentException::class.java) { resolveUiTarget(request) { "app.fixture.current" } }
        }
    }

    @Test fun gesturesRemainBoundToThePackageReturnedInTheScreenshot() {
        val request = capture().copy(action = ExecutionAction.PERFORM_GESTURES,
            arguments = mapOf("packageName" to "app.fixture.bound"), target = ExecutionTarget(packageName = "app.fixture.bound"))
        assertEquals("app.fixture.bound", resolveUiTarget(request) { error("must not silently retarget gestures") })
        assertThrows(IllegalArgumentException::class.java) { resolveUiTarget(request.copy(target = ExecutionTarget(packageName = "app.fixture.other"))) { null } }
    }
}
