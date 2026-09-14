package app.xiangyue.phase.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.view.accessibility.AccessibilityEvent
import app.xiangyue.phase.PhaseApplication
import app.xiangyue.phase.vision.VisualDriver

class PhaseAccessibilityService : AccessibilityService() {
    lateinit var driver: AccessibilityDriver
        private set
    lateinit var overlay: TaskOverlay
        private set
    lateinit var visual: VisualDriver
        private set
    private val coordinator get() = (application as PhaseApplication).runtime.coordinator
    private val screenOff = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { coordinator.interruptDevice("locked") }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        driver = AccessibilityDriver(this); overlay = TaskOverlay(this); visual = VisualDriver(this)
        instance = this
        if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(screenOff, IntentFilter(Intent.ACTION_SCREEN_OFF), Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(screenOff, IntentFilter(Intent.ACTION_SCREEN_OFF))
        coordinator.accessibilityChanged()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!::driver.isInitialized) return
        driver.changed()
        coordinator.windowChanged(driver.activePackage())
    }

    override fun onInterrupt() { coordinator.interruptDevice("permissionRequired") }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (::overlay.isInitialized) { overlay.hide(); coordinator.refreshOverlay() }
    }

    override fun onDestroy() {
        if (::overlay.isInitialized) overlay.hide()
        if (::driver.isInitialized) driver.clear()
        if (::visual.isInitialized) visual.clear()
        try { unregisterReceiver(screenOff) } catch (_: IllegalArgumentException) {}
        instance = null
        coordinator.interruptDevice("permissionRequired")
        coordinator.accessibilityChanged()
        super.onDestroy()
    }

    companion object { var instance: PhaseAccessibilityService? = null; private set }
}
