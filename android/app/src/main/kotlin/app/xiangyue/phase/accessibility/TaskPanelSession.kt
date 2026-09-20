package app.xiangyue.phase.accessibility

import app.xiangyue.phase.bridge.TaskPanelSnapshot
import kotlin.math.roundToInt

/** Presentation only. A continuation identifies exactly one Dart tool call. */
class TaskPanelSession {
    var runId: String? = null
        private set
    var snapshot: TaskPanelSnapshot? = null
        private set
    var finished = false
        private set
    var continuing = false
        private set
    val waitingForUser get() = !finished && snapshot?.waitingToolCallId != null

    fun begin(id: String) {
        if (runId == id && !finished) return
        clear()
        runId = id
    }

    fun update(value: TaskPanelSnapshot) {
        if (runId != value.runId || finished) return
        if (snapshot?.waitingToolCallId != value.waitingToolCallId) continuing = false
        snapshot = value.copy(
            status = value.status.take(100),
            messages = value.messages.takeLast(6).map { it.copy(label = it.label.take(100), text = it.text.takeLast(481)) },
            userPrompt = value.userPrompt?.take(500),
        )
    }

    fun takeContinue(id: String, callId: String): Boolean {
        if (id != runId || !waitingForUser || continuing || snapshot?.waitingToolCallId != callId) return false
        continuing = true
        return true
    }

    fun finish(id: String) {
        if (id != runId) return
        finished = true
        snapshot = null // Do not keep conversation fragments in the idle launcher.
        continuing = false
    }

    fun dismiss(id: String): Boolean {
        if (runId != id || !finished) return false
        clear()
        return true
    }

    fun clear() { runId = null; snapshot = null; finished = false; continuing = false }
}

/** Normalized vertical position survives expansion, rotation and temporary hiding for capture. */
class TaskPanelPosition {
    var right = true
        private set
    private var fraction = 0.35f

    fun place(width: Int, height: Int, panelWidth: Int, panelHeight: Int): Pair<Int, Int> {
        val x = if (right) (width - panelWidth).coerceAtLeast(0) else 0
        return x to (height * fraction).roundToInt().coerceIn(0, (height - panelHeight).coerceAtLeast(0))
    }

    fun dock(x: Int, y: Int, width: Int, height: Int, panelWidth: Int, panelHeight: Int) {
        right = x + panelWidth / 2 >= width / 2
        if (height > 0) fraction = y.coerceIn(0, (height - panelHeight).coerceAtLeast(0)).toFloat() / height
    }
}


/** The actual touchable window, not a full-screen animation surface. */
data class TaskPanelFrame(val x: Int, val y: Int, val width: Int, val height: Int) {
    fun towards(target: TaskPanelFrame, progress: Float): TaskPanelFrame {
        val t = progress.coerceIn(0f, 1f)
        fun mix(a: Int, b: Int) = (a + (b - a) * t).roundToInt()
        return TaskPanelFrame(mix(x, target.x), mix(y, target.y), mix(width, target.width), mix(height, target.height))
    }
}
