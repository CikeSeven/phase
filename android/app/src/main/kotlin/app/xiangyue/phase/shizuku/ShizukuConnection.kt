package app.xiangyue.phase.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import rikka.shizuku.Shizuku

internal class ShizukuConnection(private val context: Context, private val changed: () -> Unit, private val disconnected: () -> Unit) {
    private val mutex = Mutex()
    @Volatile var remote: IDeviceUserService? = null
        private set
    private var connection: ServiceConnection? = null
    private var args: Shizuku.UserServiceArgs? = null
    private var pending: CompletableDeferred<IDeviceUserService>? = null
    init {
        Shizuku.addBinderReceivedListenerSticky { changed() }
        Shizuku.addBinderDeadListener { remote = null; pending?.completeExceptionally(IllegalStateException("channelDisconnected")); disconnected(); changed() }
        Shizuku.addRequestPermissionResultListener { _, _ -> changed() }
    }
    fun permission(): Boolean = runCatching { running() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED }.getOrDefault(false)
    fun uid(): Int = runCatching { Shizuku.getUid() }.getOrDefault(-1)
    fun running(): Boolean = runCatching { Shizuku.pingBinder() }.getOrDefault(false)
    suspend fun get(): IDeviceUserService = mutex.withLock {
        check(permission())
        remote?.takeIf { it.asBinder().pingBinder() }?.let { return@withLock it }
        val ready = CompletableDeferred<IDeviceUserService>()
        val serviceArgs = Shizuku.UserServiceArgs(ComponentName(context, ShizukuDeviceService::class.java))
            .tag("phase.device").processNameSuffix("device").version(3).daemon(false)
        val listener = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                if (connection !== this || ready.isCompleted) return
                val service = IDeviceUserService.Stub.asInterface(binder)
                if (service == null) ready.completeExceptionally(IllegalStateException("channelDisconnected"))
                else { remote = service; ready.complete(service) }
            }
            override fun onServiceDisconnected(name: ComponentName?) {
                if (connection !== this) return
                remote = null
                ready.completeExceptionally(IllegalStateException("channelDisconnected"))
                disconnected(); changed()
            }
        }
        args = serviceArgs; connection = listener; pending = ready
        try {
            withContext(Dispatchers.Main) { Shizuku.bindUserService(serviceArgs, listener) }
            withTimeout(15000) { ready.await() }
        } catch (error: Exception) {
            connection = null; remote = null
            withContext(NonCancellable + Dispatchers.Main) { runCatching { Shizuku.unbindUserService(serviceArgs, listener, true) } }
            throw error
        } finally { if (pending === ready) pending = null }
    }
    /** Main-thread only, after the last owner has been released; never detach a newer binding. */
    fun disconnect(expected: IDeviceUserService) {
        if (remote !== expected || pending != null) return
        val listener = connection ?: return
        val serviceArgs = args ?: return
        remote = null; connection = null; args = null
        runCatching { Shizuku.unbindUserService(serviceArgs, listener, true) }
    }

}
