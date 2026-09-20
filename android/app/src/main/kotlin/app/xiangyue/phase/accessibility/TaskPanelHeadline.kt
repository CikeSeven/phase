package app.xiangyue.phase.accessibility

import app.xiangyue.phase.bridge.TaskPanelMessageKind
import app.xiangyue.phase.bridge.TaskPanelPhase
import app.xiangyue.phase.bridge.TaskPanelSnapshot

data class TaskPanelHeadline(val text: String, val responseId: String? = null) {
    companion object {
        fun from(snapshot: TaskPanelSnapshot?, expanded: Boolean, confirming: Boolean, continuing: Boolean): TaskPanelHeadline {
            if (confirming) return TaskPanelHeadline("等待确认")
            if (continuing) return TaskPanelHeadline("正在交还控制")
            if (snapshot?.waitingToolCallId != null) return TaskPanelHeadline("等待你操作")
            if (!expanded && snapshot?.phase == TaskPanelPhase.RESPONDING) {
                snapshot.messages.lastOrNull { it.kind == TaskPanelMessageKind.TEXT && it.text.isNotBlank() }?.let {
                    return TaskPanelHeadline(it.text, it.id)
                }
            }
            return TaskPanelHeadline(snapshot?.status ?: "正在处理")
        }
    }
}
