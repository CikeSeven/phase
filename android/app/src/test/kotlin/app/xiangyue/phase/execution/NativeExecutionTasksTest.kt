package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test

class NativeExecutionTasksTest {
    private fun request(id: String = "app-call", timeout: Long = 1000) = ExecutionRequest(
        "run", id, ExecutionAction.CLICK_NODE, emptyMap(), ExecutionTarget(), timeout,
    )
    private fun success(id: String) = ExecutionResult(id, ExecutionStatus.SUCCEEDED, mapOf("observed" to true), emptyList())

    @Test fun unimplementedActionsAreUnavailable() = runBlocking {
        val tasks = NativeExecutionTasks(this, emptyMap()) {}
        tasks.begin("run")
        assertTrue(tasks.capabilities.isEmpty())
        assertEquals(ChannelError.UNAVAILABLE, tasks.execute(request()).error)
    }

    @Test fun duplicateIdDoesNotExecuteAgainAndProgressIsNotResult() = runBlocking {
        var dispatched = 0
        val progress = mutableListOf<ExecutionProgress>()
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.CLICK_NODE to NativeAction { req, emit ->
            dispatched++
            emit(ProgressKind.STAGE, "accepted")
            emit(ProgressKind.STAGE, "observed")
            emit(ProgressKind.STAGE, "x".repeat(5000))
            success(req.toolCallId)
        }), progress::add)
        tasks.begin("run")
        assertEquals(ExecutionStatus.SUCCEEDED, tasks.execute(request()).status)
        assertEquals(listOf(1L, 2L), progress.map { it.sequence })
        assertEquals(ChannelError.INVALID_ARGUMENTS, tasks.execute(request()).error)
        assertEquals(1, dispatched)
    }

    @Test fun cancellationReachesRunningDriverAndLeavesUnknownEffect() = runBlocking {
        val dispatched = CompletableDeferred<Unit>()
        var cancelled = false
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.CLICK_NODE to NativeAction { _, _ ->
            dispatched.complete(Unit)
            try { awaitCancellation() } finally { cancelled = true }
        })) {}
        tasks.begin("run")
        val result = async { tasks.execute(request()) }
        dispatched.await()
        tasks.cancel("app-call")
        assertEquals(ExecutionStatus.UNKNOWN, result.await().status)
        assertTrue(cancelled)
    }

    @Test fun stopLatchesBeforeNewDispatchAndOldStopCannotCancelNewRun() = runBlocking {
        var dispatched = 0
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.CLICK_NODE to NativeAction { req, _ ->
            dispatched++; success(req.toolCallId)
        })) {}
        tasks.begin("run")
        tasks.stop("run")
        assertEquals(ExecutionStatus.CANCELLED, tasks.execute(request()).status)
        assertEquals(0, dispatched)
        tasks.end("run")
        tasks.begin("next")
        tasks.stop("run")
        assertEquals(ExecutionStatus.SUCCEEDED, tasks.execute(request().copy(runId = "next")).status)
        assertEquals(1, dispatched)
    }

    @Test fun timeoutAndWrongIdCannotReportSuccess() = runBlocking {
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.CLICK_NODE to NativeAction { req, _ ->
            if (req.toolCallId == "timeout") awaitCancellation()
            success("provider-call")
        })) {}
        tasks.begin("run")
        assertEquals(ExecutionStatus.UNKNOWN, tasks.execute(request("timeout", 10)).status)
        assertEquals(ExecutionStatus.UNKNOWN, tasks.execute(request()).status)
    }

    @Test fun endRunCancelsChildrenInsteadOfReplayingAfterRestart() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.CLICK_NODE to NativeAction { _, _ ->
            started.complete(Unit); awaitCancellation()
        })) {}
        tasks.begin("run")
        val result = async { tasks.execute(request()) }
        started.await()
        tasks.end("run")
        assertEquals(ExecutionStatus.UNKNOWN, result.await().status)
        assertNull(tasks.runId)
        assertEquals(ExecutionStatus.CANCELLED, tasks.execute(request()).status)
    }
}
