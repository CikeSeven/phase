package app.xiangyue.phase.commands

import android.content.Context
import android.content.Intent
import android.net.Uri
import app.xiangyue.phase.bridge.commands.CommandChannelFlutterApi
import app.xiangyue.phase.bridge.commands.CommandChannelHostApi
import app.xiangyue.phase.bridge.commands.CommandChannelStatus
import app.xiangyue.phase.bridge.commands.FlutterError
import app.xiangyue.phase.shizuku.ShizukuDeviceHost
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

class CommandChannelHost(
    private val context: Context,
    private val flutter: CommandChannelFlutterApi,
    private val device: ShizukuDeviceHost,
) : CommandChannelHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val setupMutex = Mutex()

    init { device.onStatusChanged = ::changed }

    fun changed() { scope.launch { runCatching { flutter.statusChanged() } } }

    private fun fail(code: String, message: String): Nothing = throw FlutterError(code, message, null)
    private fun validateChannel(channel: String) {
        if (channel != "shizuku") fail("invalidChannel", "系统能力通道无效")
    }

    override suspend fun status(): List<CommandChannelStatus> = withContext(Dispatchers.IO) {
        listOf(device.status())
    }

    override suspend fun authorize(channel: String) = withContext(Dispatchers.Main.immediate) {
        validateChannel(channel)
        if (device.status().state == "notRunning") fail("notRunning", "请先启动 Shizuku")
        device.authorize()
    }

    override suspend fun initialize(channel: String) = setupMutex.withLock {
        validateChannel(channel)
        try {
            device.initialize()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            fail("deviceInitializationFailed", "Shizuku 设备服务连接失败，请检查服务及授权")
        } finally {
            changed()
        }
    }

    override fun openSettings(channel: String) {
        validateChannel(channel)
        val intent = context.packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")
            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/"))
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    override suspend fun setEnabled(channels: List<String>) {
        require(channels.all { it == "shizuku" })
        device.setEnabled("shizuku" in channels)
    }
}
