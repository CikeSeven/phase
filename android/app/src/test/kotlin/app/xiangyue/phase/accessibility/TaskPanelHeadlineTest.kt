package app.xiangyue.phase.accessibility

import app.xiangyue.phase.bridge.*
import org.junit.Assert.*
import org.junit.Test

class TaskPanelHeadlineTest {
    private fun snapshot() = TaskPanelSnapshot(
        "run", TaskPanelPhase.RESPONDING, "正在回复", listOf(
            TaskPanelMessage("old", TaskPanelMessageKind.TEXT, "相月", "上一轮正文"),
            TaskPanelMessage("r", TaskPanelMessageKind.REASONING, "思考", "公开思考"),
            TaskPanelMessage("new", TaskPanelMessageKind.TEXT, "相月", "读取完成。\n原文 **加粗** 和 `代码` 😀"),
        ),
    )

    @Test fun collapsedResponseShowsOriginalBodyAndReplacesStreamingSnapshot() {
        val first = snapshot()
        val headline = TaskPanelHeadline.from(first, false, false, false)
        assertEquals(first.messages.last().text, headline.text)
        assertEquals("new", headline.responseId)
        val completed = first.copy(messages = first.messages.dropLast(1) + first.messages.last().copy(text = "完成快照里的正文"))
        val next = TaskPanelHeadline.from(completed, false, false, false)
        assertEquals("完成快照里的正文", next.text)
        assertEquals(headline.responseId, next.responseId)
    }

    @Test fun controlStatesTakePriorityAndExpandedBodyStaysInFeed() {
        val snapshot = snapshot()
        assertEquals(TaskPanelHeadline("等待确认"), TaskPanelHeadline.from(snapshot, false, true, false))
        assertEquals(TaskPanelHeadline("正在交还控制"), TaskPanelHeadline.from(snapshot, false, false, true))
        assertEquals(TaskPanelHeadline("等待你操作"), TaskPanelHeadline.from(snapshot.copy(waitingToolCallId = "wait"), false, false, false))
        assertEquals(TaskPanelHeadline("正在回复"), TaskPanelHeadline.from(snapshot, true, false, false))
        assertEquals(TaskPanelHeadline("执行了读取文件"), TaskPanelHeadline.from(
            snapshot.copy(phase = TaskPanelPhase.WAITING_MODEL, status = "执行了读取文件"), false, false, false,
        ))
    }

    @Test fun absentBodyDoesNotSubstituteReasoningOrToolText() {
        val snapshot = snapshot().copy(messages = listOf(
            TaskPanelMessage("r", TaskPanelMessageKind.REASONING, "思考", "公开思考"),
            TaskPanelMessage("tool", TaskPanelMessageKind.TOOL, "执行了命令", "pwd"),
            TaskPanelMessage("empty", TaskPanelMessageKind.TEXT, "相月", "\n  "),
        ))
        assertEquals(TaskPanelHeadline("正在回复"), TaskPanelHeadline.from(snapshot, false, false, false))
    }
}
