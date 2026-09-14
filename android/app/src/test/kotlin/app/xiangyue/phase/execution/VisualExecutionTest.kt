package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.*
import app.xiangyue.phase.vision.*
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test

class VisualExecutionTest {
    private val coordinates = GestureCoordinates(540, 1080)
    private val bounds = GestureBounds(40, 80, 1120, 2240)
    private fun plan(value: Any?) = coordinates.toScreen(GesturePlan.parse(value), bounds)
    private val tap = mapOf("type" to "tap", "x" to 100, "y" to 200)

    @Test fun imageCoordinatesMapToWindowOriginAndScale() {
        val mapped = plan(listOf(tap)).single()
        assertEquals(240.0, mapped.x!!, 0.0); assertEquals(480.0, mapped.y!!, 0.0)
        val origin = plan(listOf(mapOf("type" to "tap", "x" to 0, "y" to 0))).single()
        assertEquals(40.0, origin.x!!, 0.0); assertEquals(80.0, origin.y!!, 0.0)
        for ((x, y) in listOf(-1.0 to 0.0, 540.0 to 0.0, 0.0 to 1080.0, Double.NaN to 0.0, 0.0 to Double.POSITIVE_INFINITY)) {
            assertThrows(IllegalArgumentException::class.java) { plan(listOf(mapOf("type" to "tap", "x" to x, "y" to y))) }
        }
    }

    @Test fun entirePlanIsValidatedBeforeFirstDispatch() {
        for (rawPlan in listOf(emptyList<Any>(), List(11) { tap }, listOf(tap, mapOf("type" to "shell")),
            listOf(tap, mapOf("type" to "tap", "x" to 540, "y" to 0)),
            listOf(mapOf("type" to "tap", "x" to 1, "y" to 2, "durationMs" to 100)),
            listOf(mapOf("type" to "wait", "durationMs" to 1.5)),
            List(8) { mapOf("type" to "wait", "durationMs" to 2000) })) {
            assertThrows(IllegalArgumentException::class.java) { plan(rawPlan) }
        }
        val plan = plan(listOf(tap, mapOf("type" to "double_tap", "x" to 2, "y" to 3),
            mapOf("type" to "long_press", "x" to 2, "y" to 3),
            mapOf("type" to "swipe", "x" to 2, "y" to 3, "endX" to 10, "endY" to 30),
            mapOf("type" to "wait")))
        assertEquals(listOf("tap", "double_tap", "long_press", "swipe", "wait"), plan.map { it.type })
    }

    @Test fun screenCoordinatesDoNotRequireAnyScreenshot() {
        val screen = GestureCoordinates.parse(mapOf("packageName" to "app.xiangyue.phase", "actions" to listOf(tap)))
        val mapped = screen.toScreen(GesturePlan.parse(listOf(tap)), bounds).single()
        assertEquals(100.0, mapped.x!!, 0.0)
        assertEquals(200.0, mapped.y!!, 0.0)
        assertThrows(IllegalArgumentException::class.java) {
            screen.toScreen(GesturePlan.parse(listOf(mapOf("type" to "tap", "x" to 10, "y" to 20))), bounds)
        }
    }

    @Test fun imageCalibrationCanBeReusedAcrossNewRequestsWithoutExpirationOrConsumption() = runBlocking {
        val args = mapOf("packageName" to "app.xiangyue.phase", "coordinateSpace" to "image_pixels",
            "imageWidth" to 540, "imageHeight" to 1080, "actions" to listOf(tap))
        var dispatched = 0
        val tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.PERFORM_GESTURES to NativeAction { request, _ ->
            val steps = GestureCoordinates.parse(request.arguments).toScreen(GesturePlan.parse(request.arguments["actions"]), bounds)
            val batch = GestureBatch {}
            batch.execute(steps, {}, { dispatched++; true })
            ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, batch.state(), emptyList())
        })) {}
        tasks.begin("run")
        for (id in listOf("first", "second", "third")) {
            val result = tasks.execute(ExecutionRequest("run", id, ExecutionAction.PERFORM_GESTURES, args, ExecutionTarget(packageName = "app.xiangyue.phase"), 5000))
            assertEquals(ExecutionStatus.SUCCEEDED, result.status)
            val step = (result.result["completedSteps"] as List<*>).single() as Map<*, *>
            assertEquals(240.0, step["x"]); assertEquals(480.0, step["y"])
        }
        assertEquals(3, dispatched)
        tasks.end("run")
    }

    @Test fun malformedCalibrationAndOutOfBoundsLaterActionsNeverStartTheBatch() {
        for (args in listOf(
            mapOf("coordinateSpace" to "image_pixels", "imageWidth" to 540),
            mapOf("coordinateSpace" to "image_pixels", "imageWidth" to 0, "imageHeight" to 10),
            mapOf("coordinateSpace" to "image_pixels", "imageWidth" to 3.5, "imageHeight" to 10),
            mapOf("coordinateSpace" to "screen_pixels", "imageWidth" to 100),
            mapOf("coordinateSpace" to "normalized"),
        )) assertThrows(IllegalArgumentException::class.java) { GestureCoordinates.parse(args) }
        assertThrows(IllegalArgumentException::class.java) {
            plan(listOf(tap, mapOf("type" to "tap", "x" to 540, "y" to 100)))
        }
    }

    @Test fun rejectionStopsSequenceAndRetainsActualCallbacks() = runBlocking {
        val checkpoints = mutableListOf<Map<String, Any?>>()
        val batch = GestureBatch(checkpoints::add)
        var sent = 0
        assertFalse(batch.execute(plan(List(3) { tap }), {}, { ++sent == 1 }))
        assertEquals(2, sent)
        assertEquals(1, batch.state()["completedCount"])
        assertEquals(0, checkpoints.first()["completedCount"])
        assertEquals(2, (batch.state()["completedSteps"] as List<*>).size)
    }

    @Test fun permissionOrGeometryChangeBeforeNextStepDoesNotDispatchIt() = runBlocking {
        var validations = 0; var sent = 0
        val batch = GestureBatch {}
        try {
            batch.execute(plan(List(3) { tap }), {
                if (++validations == 2) throw VisualBlocked("targetChanged")
            }, { sent++; true })
            fail("must stop")
        } catch (error: VisualBlocked) { assertEquals("targetChanged", error.reason) }
        assertEquals(1, sent)
        assertEquals(1, batch.state()["completedCount"])
        assertEquals(false, batch.state()["activeStepDispatched"])
    }

    @Test fun nativeCancelAndTimeoutPreservePartialBatchWithoutReplay() = runBlocking {
        for (timeout in listOf(false, true)) {
            val entered = CompletableDeferred<Unit>()
            var sent = 0
            lateinit var tasks: NativeExecutionTasks
            tasks = NativeExecutionTasks(this, mapOf(ExecutionAction.PERFORM_GESTURES to NativeAction { request, _ ->
                val batch = GestureBatch { tasks.checkpoint(request.toolCallId, it) }
                batch.execute(plan(List(3) { tap }), {}, {
                    if (++sent == 2) { entered.complete(Unit); awaitCancellation() }
                    true
                })
                error("must stop")
            })) {}
            tasks.begin("run")
            val request = ExecutionRequest("run", "call", ExecutionAction.PERFORM_GESTURES, emptyMap(), ExecutionTarget(), if (timeout) 50 else 5000)
            val pending = async { tasks.execute(request) }
            entered.await()
            if (!timeout) tasks.cancel("call")
            val result = pending.await()
            assertEquals(if (timeout) ChannelError.TIMEOUT else ChannelError.CANCELLED, result.error)
            assertEquals(1, result.result["completedCount"])
            assertEquals(1, result.result["activeStep"])
            assertEquals(true, result.result["activeStepDispatched"])
            assertEquals(2, sent)
            assertEquals(ChannelError.INVALID_ARGUMENTS, tasks.execute(request).error)
            tasks.end("run")
        }
    }
}
