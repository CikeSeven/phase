package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*

fun interface NativeAction {
    suspend fun execute(request: ExecutionRequest, progress: suspend (ProgressKind, String) -> Unit): ExecutionResult
}

/** Main-thread confined. Run ownership is isolated while device actions share a native queue. */
class NativeExecutionTasks(
    private val scope: CoroutineScope,
    private val actions: Map<ExecutionAction, NativeAction>,
    private val emit: (ExecutionProgress) -> Unit,
) {
    private class RunState {
        val seen = mutableSetOf<String>()
        var stopped = false
    }

    private class Pending(val runId: String) {
        var sequence = 0L
        var lastProgressAt = 0L
        var checkpoint: Map<String, Any?> = emptyMap()
        lateinit var job: Deferred<ExecutionResult>
    }

    private val runs = mutableMapOf<String, RunState>()
    private val pending = mutableMapOf<String, Pending>()
    val capabilities get() = actions.keys.toList()

    fun contains(runId: String) = runId in runs

    fun checkpoint(runId: String, id: String, value: Map<String, Any?>) {
        pending[id]?.takeIf { it.runId == runId }?.checkpoint = value.toMap()
    }

    private fun interrupted(id: String, task: Pending, status: ExecutionStatus, error: ChannelError) =
        if (task.checkpoint.isEmpty()) result(id, status, error)
        else ExecutionResult(id, status, task.checkpoint + ("reason" to error.name.lowercase()), emptyList(), error)

    fun begin(runId: String) {
        check(runId.isNotBlank())
        runs.putIfAbsent(runId, RunState())
    }

    suspend fun execute(request: ExecutionRequest): ExecutionResult {
        val id = request.toolCallId
        val run = runs[request.runId]
        if (run == null || run.stopped) return result(id, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
        if (id.isBlank() || request.timeoutMs !in 1..300000 || !run.seen.add(id)) {
            return result(id, ExecutionStatus.FAILED, ChannelError.INVALID_ARGUMENTS)
        }
        val action = actions[request.action]
            ?: return result(id, ExecutionStatus.FAILED, ChannelError.UNAVAILABLE)
        val task = Pending(request.runId)
        pending[id] = task
        task.job = scope.async(start = CoroutineStart.LAZY) {
            try {
                withTimeout(request.timeoutMs) {
                    ensureActive()
                    val response = action.execute(request) { kind, payload ->
                        withContext(scope.coroutineContext.minusKey(Job)) {
                            val now = System.nanoTime()
                            if (pending[id] === task && !run.stopped && payload.toByteArray().size <= 4096 &&
                                (kind == ProgressKind.STAGE || now - task.lastProgressAt >= 100_000_000)) {
                                task.lastProgressAt = now
                                emit(ExecutionProgress(id, ++task.sequence, kind, payload))
                            }
                        }
                    }
                    if (response.toolCallId == id) response else result(id, ExecutionStatus.FAILED, ChannelError.EXECUTION_FAILED)
                }
            } catch (_: TimeoutCancellationException) {
                interrupted(id, task, ExecutionStatus.FAILED, ChannelError.TIMEOUT)
            } catch (_: CancellationException) {
                interrupted(id, task, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
            } catch (_: Exception) {
                result(id, ExecutionStatus.FAILED, ChannelError.EXECUTION_FAILED)
            }
        }
        return try {
            task.job.await()
        } catch (_: CancellationException) {
            task.job.cancel()
            interrupted(id, task, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
        } finally {
            if (pending[id] === task) pending.remove(id)
        }
    }

    fun cancel(toolCallId: String) { pending[toolCallId]?.job?.cancel() }

    fun stop(runId: String) {
        val run = runs[runId] ?: return
        run.stopped = true
        pending.values.filter { it.runId == runId }.forEach { it.job.cancel() }
    }

    fun end(runId: String) {
        stop(runId)
        runs.remove(runId)
    }

    companion object {
        fun result(id: String, status: ExecutionStatus, error: ChannelError) =
            ExecutionResult(id, status, emptyMap(), emptyList(), error)
    }
}
