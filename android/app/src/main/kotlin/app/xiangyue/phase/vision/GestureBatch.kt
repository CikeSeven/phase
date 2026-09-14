package app.xiangyue.phase.vision

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/** Immutable checkpoints survive timeout/cancellation. A dispatched gesture is never replayed. */
class GestureBatch(private val checkpoint: (Map<String, Any?>) -> Unit) {
    private val completed = mutableListOf<Map<String, Any?>>()
    private var active: Int? = null
    private var dispatched = false
    private var activeAction: Map<String, Any?>? = null
    fun state(): Map<String, Any?> = mapOf(
        "completedSteps" to completed.toList(), "completedCount" to completed.count { it["actionAccepted"] == true },
        "activeStep" to active, "activeStepDispatched" to dispatched,
        "activeAction" to activeAction, "coordinateSpace" to "screen_pixels",
    )
    suspend fun execute(
        steps: List<GestureStep>,
        validate: suspend () -> Unit,
        dispatch: suspend (GestureStep) -> Boolean,
    ): Boolean {
        checkpoint(state())
        for ((index, step) in steps.withIndex()) {
            currentCoroutineContext().ensureActive()
            active = index; activeAction = describe(step); dispatched = false; checkpoint(state())
            validate()
            currentCoroutineContext().ensureActive()
            dispatched = step.type != "wait"; checkpoint(state())
            val accepted = dispatch(step)
            currentCoroutineContext().ensureActive()
            completed.add(describe(step) + mapOf("index" to index, "actionAccepted" to accepted))
            active = null; activeAction = null; dispatched = false; checkpoint(state())
            if (!accepted) return false
        }
        return true
    }

    private fun describe(step: GestureStep): Map<String, Any?> = buildMap {
        put("type", step.type); put("durationMs", step.durationMs)
        if (step.x != null) { put("x", step.x); put("y", step.y) }
        if (step.endX != null) { put("endX", step.endX); put("endY", step.endY) }
    }
}
