package app.xiangyue.phase.shizuku

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.UiAutomation
import android.content.Context
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import java.lang.reflect.Proxy

/** A short-lived, text-only automation connection in the already authorized UserService. */
internal class DisplayTextConnection(private val context: Context, private val target: String) {
    private val clientType = Class.forName("android.accessibilityservice.IAccessibilityServiceClient")
    private val managerType = Class.forName("android.view.accessibility.IAccessibilityManager")
    private val manager = Class.forName("android.view.accessibility.IAccessibilityManager\$Stub")
        .getMethod("asInterface", IBinder::class.java).invoke(null,
            Class.forName("android.os.ServiceManager").getMethod("getService", String::class.java)
                .invoke(null, Context.ACCESSIBILITY_SERVICE))
    private val token = Binder()
    private var client: Any? = null
    private var automation: UiAutomation? = null

    fun open(display: Display): UiAutomation {
        // The Context constructor and user-scoped registration below are the Android 14+ API.
        if (Build.VERSION.SDK_INT < 34) throw DisplayTextFault("textConnectionUnavailable")
        val connectionType = Class.forName("android.app.IUiAutomationConnection")
        val connection = Proxy.newProxyInstance(connectionType.classLoader, arrayOf(connectionType)) { proxy, method, args ->
            when (method.name) {
                "asBinder" -> token
                "connect" -> {
                    // Let UiAutomation's bounded wait finish even if registration is rejected.
                    // Throwing here leaves its callback thread stuck in CONNECTING on Android 14+.
                    runCatching { register(requireNotNull(args?.get(0))) }
                    null
                }
                "disconnect" -> { unregister(); null }
                "toString" -> "DisplayTextConnection"
                "hashCode" -> System.identityHashCode(proxy)
                "equals" -> proxy === args?.get(0)
                else -> throw UnsupportedOperationException("Text connection only")
            }
        }
        val value = UiAutomation::class.java.getConstructor(Context::class.java, connectionType)
            .newInstance(context.createDisplayContext(display), connection)
        automation = value
        UiAutomation::class.java.getMethod("connectWithTimeout", Int::class.javaPrimitiveType, Long::class.javaPrimitiveType)
            .invoke(value, UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES, 3000L)
        return value
    }

    private fun register(value: Any) {
        val info = AccessibilityServiceInfo().apply {
            packageNames = arrayOf(target)
            eventTypes = AccessibilityEvent.TYPE_VIEW_FOCUSED or AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or AccessibilityEvent.TYPE_WINDOWS_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }
        AccessibilityServiceInfo::class.java.getMethod("setCapabilities", Int::class.javaPrimitiveType)
            .invoke(info, AccessibilityServiceInfo.CAPABILITY_CAN_RETRIEVE_WINDOW_CONTENT)
        val userId = Class.forName("android.os.UserHandle").getMethod("getUserId", Int::class.javaPrimitiveType)
            .invoke(null, context.applicationInfo.uid)
        // Do not use UiAutomationConnection: its disconnect restores the main screen's rotation.
        // Register only the node connection; do not expose shell, permission or input injection APIs.
        managerType.getMethod("registerUiTestAutomationService", IBinder::class.java, clientType,
            AccessibilityServiceInfo::class.java, Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
            .invoke(manager, token, value, info, userId, UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        client = value
    }

    private fun unregister() {
        val value = client ?: return
        managerType.getMethod("unregisterUiTestAutomationService", clientType).invoke(manager, value)
        client = null
    }

    fun close(): Boolean {
        val disconnected = runCatching {
            automation?.let { UiAutomation::class.java.getMethod("disconnect").invoke(it) }
        }.isSuccess
        automation = null
        // Retry only resource cleanup, never the text action or another service's registration.
        val released = runCatching { unregister() }.isSuccess
        return disconnected && released
    }
}

internal class DisplayTextFault(val code: String) : Exception()
