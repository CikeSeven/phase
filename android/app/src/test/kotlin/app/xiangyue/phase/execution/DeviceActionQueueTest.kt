package app.xiangyue.phase.execution

import app.xiangyue.phase.accessibility.DeviceActionQueue
import app.xiangyue.phase.files.AppFileDriver
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test

class DeviceActionQueueTest {
    @Test fun serializesActionAndObservationAndDropsCancelledWaiters() = runBlocking {
        val queue = DeviceActionQueue()
        val gate = CompletableDeferred<Unit>()
        val entered = CompletableDeferred<Unit>()
        val order = mutableListOf<String>()
        val first = launch { queue.withLock { order.add("first-action"); entered.complete(Unit); gate.await(); order.add("first-observation") } }
        entered.await()
        val cancelled = launch { queue.withLock { order.add("cancelled-action") } }
        val next = launch { queue.withLock { order.add("next-action") } }
        yield(); cancelled.cancelAndJoin()
        assertEquals(listOf("first-action"), order)
        gate.complete(Unit); first.join(); next.join()
        assertEquals(listOf("first-action", "first-observation", "next-action"), order)
    }
    @Test fun exceptionReleasesQueue() = runBlocking {
        val queue = DeviceActionQueue()
        try { queue.withLock { throw IllegalStateException("fixture") } } catch (_: IllegalStateException) {}
        assertEquals("next", queue.withLock { "next" })
    }
    @Test fun externalNamesCannotEscapeAndHashIsStable() {
        for (name in listOf("", ".", "..", "../x", "/x", "x/y", "x\\y", "x\u0000")) {
            assertThrows(IllegalArgumentException::class.java) { AppFileDriver.safeName(name) }
        }
        assertEquals("摘要.txt", AppFileDriver.safeName("摘要.txt"))
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", AppFileDriver.hash("abc".toByteArray()))
    }
}
