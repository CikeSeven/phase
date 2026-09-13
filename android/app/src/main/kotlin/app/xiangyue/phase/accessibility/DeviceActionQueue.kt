package app.xiangyue.phase.accessibility

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Held only for observe/action/observe, never while waiting for a user decision. */
class DeviceActionQueue {
    private val mutex = Mutex()
    suspend fun <T> withLock(action: suspend () -> T): T = mutex.withLock { action() }
}
