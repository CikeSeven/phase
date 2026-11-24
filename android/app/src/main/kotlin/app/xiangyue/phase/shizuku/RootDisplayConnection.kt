package app.xiangyue.phase.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.Process
import androidx.annotation.Keep
import com.topjohnwu.superuser.ipc.RootService
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

internal class RootDisplayConnection(
    private val context: Context,
    private val disconnected: () -> Unit,
) : DisplayConnection {
    private val mutex = Mutex()
    private var listener: ServiceConnection? = null
    override var remote: IDeviceUserService? = null
        private set

    override suspend fun get(): IDeviceUserService = withContext(Dispatchers.Main.immediate) {
        mutex.withLock {
            remote?.takeIf { it.asBinder().isBinderAlive }?.let { return@withLock it }
            listener?.let(RootService::unbind)
            listener = null
            remote = null
            val ready = CompletableDeferred<IDeviceUserService>()
            val connection = object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                    if (listener !== this) {
                        RootService.unbind(this)
                        return
                    }
                    val service = IDeviceUserService.Stub.asInterface(binder)
                    if (service == null) ready.completeExceptionally(IllegalStateException("rootDisplayDisconnected"))
                    else ready.complete(service)
                }

                override fun onServiceDisconnected(name: ComponentName?) {
                    if (listener !== this) return
                    listener = null
                    remote = null
                    ready.completeExceptionally(IllegalStateException("rootDisplayDisconnected"))
                    disconnected()
                }
            }
            listener = connection
            try {
                RootService.bind(Intent(context, RootVirtualDisplayService::class.java), connection)
                val service = withTimeout(12000) { ready.await() }
                val probe = withContext(Dispatchers.IO) { service.probe() }
                check(listener === connection && probe.getInt("uid", -1) == 0 &&
                    probe.getString("revision") == ShizukuDeviceService.REVISION)
                remote = service
                service
            } catch (error: Exception) {
                if (listener === connection) listener = null
                RootService.unbind(connection)
                throw error
            }
        }
    }

    override fun disconnect(expected: IDeviceUserService) {
        if (remote !== expected) return
        val connection = listener
        remote = null
        listener = null
        connection?.let(RootService::unbind)
    }
}

@Keep
class RootVirtualDisplayService : RootService() {
    private lateinit var device: ShizukuDeviceService

    override fun onCreate() {
        check(Process.myUid() == 0)
        device = ShizukuDeviceService(this)
    }

    override fun onBind(intent: Intent): IBinder = device

    override fun onDestroy() {
        if (::device.isInitialized) device.releaseAll()
    }
}
