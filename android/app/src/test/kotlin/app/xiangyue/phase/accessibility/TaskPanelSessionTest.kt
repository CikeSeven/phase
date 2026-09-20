package app.xiangyue.phase.accessibility

import app.xiangyue.phase.bridge.*
import org.junit.Assert.*
import org.junit.Test

class TaskPanelSessionTest {
    private fun snapshot(run: String = "run", call: String? = "call") = TaskPanelSnapshot(
        run, TaskPanelPhase.WAITING_USER, "等待你操作", listOf(TaskPanelMessage("r", TaskPanelMessageKind.REASONING, "思考", "公开思考")), call, "请手动登录",
    )

    @Test fun continuationIsBoundToOneActiveCall() {
        val panel = TaskPanelSession()
        panel.begin("run"); panel.update(snapshot())
        assertTrue(panel.waitingForUser)
        assertFalse(panel.takeContinue("old", "call"))
        assertFalse(panel.takeContinue("run", "old"))
        assertTrue(panel.takeContinue("run", "call"))
        panel.update(snapshot())
        assertFalse(panel.takeContinue("run", "call"))
        panel.update(snapshot(call = "next"))
        assertTrue(panel.takeContinue("run", "next"))
        panel.update(snapshot(call = null))
        assertFalse(panel.waitingForUser)
    }

    @Test fun completionRetainsOnlyLauncherUntilClosedOrNextTask() {
        val panel = TaskPanelSession()
        panel.begin("run"); panel.update(snapshot())
        panel.finish("old")
        assertFalse(panel.finished)
        panel.finish("run")
        assertEquals("run", panel.runId)
        assertTrue(panel.finished)
        assertNull(panel.snapshot)
        panel.update(snapshot())
        assertNull(panel.snapshot)
        assertFalse(panel.takeContinue("run", "call"))
        panel.begin("next")
        panel.update(snapshot())
        assertFalse(panel.finished)
        assertNull(panel.snapshot)
        panel.clear()
        assertNull(panel.runId)
    }

    @Test fun returnOrCloseDismissesTerminalAcrossLaterUpdates() {
        val panel = TaskPanelSession()
        panel.begin("run"); panel.update(snapshot())
        assertFalse(panel.dismiss("run"))
        panel.finish("run")
        assertFalse(panel.dismiss("old"))
        assertTrue(panel.dismiss("run"))
        panel.update(snapshot()); panel.finish("run")
        assertNull(panel.runId)
        assertNull(panel.snapshot)
        assertFalse(panel.dismiss("run"))
        panel.begin("next")
        assertFalse(panel.dismiss("run"))
        assertEquals("next", panel.runId)
    }

    @Test fun messageListIsBoundedAndKeepsItsOrder() {
        val panel = TaskPanelSession()
        panel.begin("run")
        panel.update(snapshot().copy(messages = (0..9).map {
            TaskPanelMessage("m$it", TaskPanelMessageKind.TEXT, "相月", "月".repeat(2000))
        }))
        assertEquals((4..9).map { "m$it" }, panel.snapshot!!.messages.map { it.id })
        assertTrue(panel.snapshot!!.messages.all { it.text.length <= 481 })
    }

    @Test fun interruptedMorphStartsAtItsCurrentFrameAndKeepsRightEdge() {
        val compact = TaskPanelFrame(184, 200, 168, 64)
        val expanded = TaskPanelFrame(88, 200, 264, 200)
        val halfway = compact.towards(expanded, 0.5f)
        assertEquals(352, halfway.x + halfway.width)
        assertEquals(200, halfway.y)
        assertEquals(halfway, halfway.towards(compact, 0f))
        assertEquals(compact, halfway.towards(compact, 1f))
        assertEquals(compact, compact.towards(expanded, -1f))
        assertEquals(expanded, compact.towards(expanded, 2f))
    }

    @Test fun dockingClampsAndSurvivesExpansionAndRotation() {
        val position = TaskPanelPosition()
        position.dock(0, 200, 360, 720, 224, 64)
        assertEquals(0 to 200, position.place(360, 720, 272, 240))
        position.dock(-10, 999, 360, 720, 224, 64)
        assertEquals(0 to 656, position.place(360, 720, 224, 64))
        assertEquals(0 to 480, position.place(360, 720, 272, 240))
        position.dock(500, -5, 720, 360, 272, 240)
        assertEquals(448 to 0, position.place(720, 360, 272, 240))
        assertEquals(256 to 0, position.place(360, 720, 104, 64))
        assertEquals(0 to 0, position.place(100, 50, 224, 64))
    }
}
