package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*

/** Drivers own the threading/cancellation of their system API. No driver is registered until implemented. */
fun interface NativeAction {
    suspend fun execute(request: ExecutionRequest, progress: suspend (ProgressKind, String) -> Unit): ExecutionResult
}

/** Main-thread confined. No business database and no replay of an already dispatched call. */
class NativeExecutionTasks(
    private val scope: CoroutineScope,
    private val actions: Map<ExecutionAction, NativeAction>,
    private val emit: (ExecutionProgress) -> Unit,
) {
    private class Pending {
        var sequence = 0L
        var lastProgressAt = 0L
        lateinit var job: Deferred<ExecutionResult>
    }
    private val pending = mutableMapOf<String, Pending>()
    private val seen = mutableSetOf<String>()
    var runId: String? = null
        private set
    private var stopped = false

    val capabilities get() = actions.keys.toList()

    fun begin(run: String) {
        check(runId == null)
        runId = run
        stopped = false
        seen.clear()
    }

    suspend fun execute(request: ExecutionRequest): ExecutionResult {
        val id = request.toolCallId
        if (request.runId != runId || stopped) return result(id, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
        if (id.isBlank() || request.timeoutMs !in 1..300000 || !seen.add(id)) {
            return result(id, ExecutionStatus.FAILED, ChannelError.INVALID_ARGUMENTS)
        }
        val action = actions[request.action]
            ?: return result(id, ExecutionStatus.FAILED, ChannelError.UNAVAILABLE)
        val task = Pending()
        pending[id] = task
        task.job = scope.async(start = CoroutineStart.LAZY) {
            try {
                withTimeout(request.timeoutMs) {
                    ensureActive()
                    val response = action.execute(request) { kind, payload ->
                        // File drivers may report from IO; maps and Pigeon delivery stay on main.
                        withContext(scope.coroutineContext.minusKey(Job)) {
                            val now = System.nanoTime()
                            if (pending[id] === task && !stopped && payload.toByteArray().size <= 4096 &&
                                (kind == ProgressKind.STAGE || now - task.lastProgressAt >= 100_000_000)) {
                                task.lastProgressAt = now
                                emit(ExecutionProgress(id, ++task.sequence, kind, payload))
                            }
                        }
                    }
                    if (response.toolCallId == id) response else result(id, ExecutionStatus.FAILED, ChannelError.EXECUTION_FAILED)
                }
            } catch (_: TimeoutCancellationException) {
                result(id, ExecutionStatus.FAILED, ChannelError.TIMEOUT)
            } catch (_: CancellationException) {
                result(id, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
            } catch (_: Exception) {
                // Do not send raw Android exception messages across the bridge.
                result(id, ExecutionStatus.FAILED, ChannelError.EXECUTION_FAILED)
            }
        }
        return try {
            task.job.await()
        } catch (_: CancellationException) {
            task.job.cancel()
            result(id, ExecutionStatus.CANCELLED, ChannelError.CANCELLED)
        } finally {
            if (pending[id] === task) pending.remove(id)
        }
    }

    fun cancel(id: String) { pending[id]?.job?.cancel() }

    fun stop(run: String) {
        if (run != runId) return
        stopped = true
        pending.values.toList().forEach { it.job.cancel() }
    }

    fun end(run: String) {
        if (run != runId) return
        stop(run)
        runId = null
        seen.clear()
    }

    companion object {
        fun result(id: String, status: ExecutionStatus, error: ChannelError) =
            ExecutionResult(id, status, emptyMap(), emptyList(), error)
    }
}
