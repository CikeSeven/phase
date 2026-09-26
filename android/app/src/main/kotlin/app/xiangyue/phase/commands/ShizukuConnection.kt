package app.xiangyue.phase.commands

import android.content.*
import android.content.pm.PackageManager
import android.os.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import rikka.shizuku.Shizuku

internal class ShizukuConnection(private val context: Context, private val changed: () -> Unit, private val disconnected: () -> Unit) {
    private val mutex = Mutex()
    private var remote: ICommandUserService? = null
    private var connection: ServiceConnection? = null
    private var args: Shizuku.UserServiceArgs? = null
    private var pending: CompletableDeferred<ICommandUserService>? = null
    private val received = Shizuku.OnBinderReceivedListener { changed() }
    private val dead = Shizuku.OnBinderDeadListener { remote = null; pending?.completeExceptionally(IllegalStateException("channelDisconnected")); disconnected(); changed() }
    private val permission = Shizuku.OnRequestPermissionResultListener { _, _ -> changed() }
    init { Shizuku.addBinderReceivedListenerSticky(received); Shizuku.addBinderDeadListener(dead); Shizuku.addRequestPermissionResultListener(permission) }
    fun permission(): Boolean = runCatching { Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED }.getOrDefault(false)
    fun uid(): Int = runCatching { Shizuku.getUid() }.getOrDefault(-1)
    fun running() = runCatching { Shizuku.pingBinder() }.getOrDefault(false)
    suspend fun get(): ICommandUserService = mutex.withLock {
        check(permission()) { "permissionRequired" }
        remote?.takeIf { it.asBinder().pingBinder() }?.let { return@withLock it }
        val value = CompletableDeferred<ICommandUserService>()
        val serviceArgs = Shizuku.UserServiceArgs(ComponentName(context, CommandUserService::class.java))
            .tag("phase.commands").processNameSuffix("commands").version(2).daemon(false)
        val listener = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                if (connection !== this) return
                val service = ICommandUserService.Stub.asInterface(binder)
                if (service == null) value.completeExceptionally(IllegalStateException("channelDisconnected")) else { remote = service; value.complete(service) }
            }
            override fun onServiceDisconnected(name: ComponentName?) {
                if (connection !== this) return
                remote = null; disconnected(); changed()
                if (!value.isCompleted) value.completeExceptionally(IllegalStateException("channelDisconnected"))
            }
        }
        args = serviceArgs; connection = listener; pending = value
        try { withContext(Dispatchers.Main) { Shizuku.bindUserService(serviceArgs, listener) }; withTimeout(15000) { value.await() } }
        catch (error: Exception) { connection = null; remote = null; runCatching { Shizuku.unbindUserService(serviceArgs, listener, true) }; throw error }
        finally { if (pending === value) pending = null }
    }
    suspend fun cancel(owner: String, call: String) { withContext(Dispatchers.IO) { remote?.cancel(owner, call) } }
}
