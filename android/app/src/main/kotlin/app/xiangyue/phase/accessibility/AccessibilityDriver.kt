package app.xiangyue.phase.accessibility

import android.accessibilityservice.GestureDescription
import android.app.KeyguardManager
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import java.util.UUID
import kotlin.coroutines.resume

/** One observation/action/observation segment at a time. Confirmation never holds this mutex. */
class AccessibilityDriver(private val service: PhaseAccessibilityService) {
    private val events = MutableStateFlow(0L)
    private data class Node(val native: AccessibilityNodeInfo, val bounds: Rect, val text: String?, val description: String?)
    private val nodes = mutableMapOf<String, Node>()
    private var snapshotId: String? = null
    private var snapshotWindow = -1
    private var snapshotPackage: String? = null
    private var snapshotFingerprint = ""

    fun changed() { events.value++ }
    fun clear() {
        nodes.values.forEach { it.native.recycle() }
        nodes.clear(); snapshotId = null; snapshotWindow = -1; snapshotPackage = null
    }

    private fun activeRoot(): AccessibilityNodeInfo? {
        val windows = service.windows
        return try { windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isActive }?.root }
        finally { windows.forEach { it.recycle() } }
    }
    fun activePackage(): String? = activeRoot()?.let { root -> try { root.packageName?.toString() } finally { root.recycle() } }

    suspend fun awaitTarget(target: String): Boolean = withTimeoutOrNull(4000) {
        while (activePackage() != target) { val last = events.value; events.first { it != last } }
        true
    } ?: false

    private fun root(target: String): AccessibilityNodeInfo {
        if (service.getSystemService(KeyguardManager::class.java).isKeyguardLocked) throw UiBlocked("locked")
        val root = activeRoot() ?: throw UiBlocked("unavailable")
        if (root.packageName?.toString() != target) { root.recycle(); throw UiBlocked("targetChanged") }
        return root
    }

    fun snapshot(target: String): Map<String, Any?> {
        val root = root(target)
        clear()
        val id = UUID.randomUUID().toString()
        val window = root.windowId
        val screen = Rect().also(root::getBoundsInScreen)
        val pending = ArrayDeque<Pair<AccessibilityNodeInfo, String?>>()
        pending.add(root to null)
        val output = mutableListOf<Map<String, Any?>>()
        var visited = 0
        var textBudget = 2400
        var truncated = false
        try {
            while (pending.isNotEmpty() && visited++ < 500 && output.size < 80) {
                val (node, parent) = pending.removeFirst()
                if (!node.isVisibleToUser) { node.recycle(); continue }
                if (manual(node)) { node.recycle(); throw UiBlocked("manualIntervention") }
                val bounds = Rect().also(node::getBoundsInScreen)
                val originalText = node.text?.toString()
                val originalDescription = node.contentDescription?.toString()
                val meaningful = node.isClickable || node.isEditable || node.isScrollable || !originalText.isNullOrBlank() || !originalDescription.isNullOrBlank()
                val nodeId = if (meaningful) "n${output.size}" else parent
                val count = minOf(node.childCount, (500 - visited - pending.size).coerceAtLeast(0))
                if (count < node.childCount) truncated = true
                for (index in 0 until count) node.getChild(index)?.let { pending.add(it to nodeId) }
                if (!meaningful) { node.recycle(); continue }
                fun clip(value: String?): String? {
                    if (value == null) return null
                    val clipped = value.take(minOf(100, textBudget))
                    textBudget -= clipped.length
                    if (clipped.length < value.length) truncated = true
                    return clipped
                }
                nodes[nodeId!!] = Node(node, bounds, originalText, originalDescription)
                output.add(mapOf("id" to nodeId, "parentId" to parent, "viewId" to node.viewIdResourceName,
                    "className" to node.className?.toString(), "text" to clip(originalText), "description" to clip(originalDescription),
                    "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom), "clickable" to node.isClickable,
                    "editable" to node.isEditable, "scrollable" to node.isScrollable, "enabled" to node.isEnabled, "focused" to node.isFocused,
                    "checkable" to node.isCheckable, "checked" to node.isChecked, "selected" to node.isSelected))
            }
            truncated = truncated || pending.isNotEmpty()
            snapshotId = id; snapshotWindow = window; snapshotPackage = target
            snapshotFingerprint = output.toString()
            return mapOf("id" to id, "capturedAt" to System.currentTimeMillis(), "packageName" to target, "windowId" to window,
                "screenBounds" to listOf(screen.left, screen.top, screen.right, screen.bottom),
                "rotation" to service.getSystemService(android.view.WindowManager::class.java).defaultDisplay.rotation,
                "truncated" to truncated, "nodes" to output)
        } catch (error: Exception) { clear(); throw error }
        finally { pending.forEach { it.first.recycle() } }
    }

    suspend fun execute(request: ExecutionRequest, target: String): ExecutionResult {
        var accepted = false
        return try {
            if (request.action == ExecutionAction.INSPECT_UI) return success(request, mapOf("snapshot" to snapshot(target)))
            val currentRoot = root(target)
            val window = currentRoot.windowId
            currentRoot.recycle()
            if (request.target.snapshotId != snapshotId || snapshotPackage != target || window != snapshotWindow) throw UiBlocked("targetChanged")
            val node = nodes[request.target.nodeId] ?: throw UiBlocked("targetChanged")
            val native = node.native
            val bounds = Rect()
            if (!native.refresh() || !native.isVisibleToUser || !native.isEnabled || native.windowId != snapshotWindow) throw UiBlocked("targetChanged")
            native.getBoundsInScreen(bounds)
            if (bounds != node.bounds || native.text?.toString() != node.text || native.contentDescription?.toString() != node.description) throw UiBlocked("targetChanged")
            if (manual(native)) throw UiBlocked("manualIntervention")
            val before = snapshotFingerprint
            val sequence = events.value
            val expected = request.arguments["text"] as? String
            val readbackNode = AccessibilityNodeInfo.obtain(native)
            try {
                accepted = when (request.action) {
                    ExecutionAction.CLICK_NODE -> if (native.isClickable) native.performAction(AccessibilityNodeInfo.ACTION_CLICK) else gesture(bounds)
                    ExecutionAction.SCROLL -> {
                        require(native.isScrollable)
                        val direction = request.arguments["direction"] as? String
                        require(direction == "forward" || direction == "backward")
                        native.performAction(if (direction == "forward") AccessibilityNodeInfo.ACTION_SCROLL_FORWARD else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)
                    }
                    ExecutionAction.INPUT_TEXT -> {
                        require(native.isEditable && expected != null && expected.length <= 2000)
                        native.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, expected) })
                    }
                    else -> throw IllegalArgumentException()
                }
                if (!accepted) return failure(request, ChannelError.EXECUTION_FAILED, "系统未接受动作", false)
                var observation: Map<String, Any?>? = null
                val observed = withTimeoutOrNull(3000) {
                    var last = sequence
                    while (true) {
                        observation = snapshot(target)
                        val confirmed = if (request.action == ExecutionAction.INPUT_TEXT)
                            readbackNode.refresh() && readbackNode.text?.toString() == expected
                        else snapshotFingerprint != before
                        if (confirmed) break
                        events.first { it != last }; last = events.value
                    }
                    true
                } ?: false
                if (!observed && request.action == ExecutionAction.INPUT_TEXT) return ExecutionResult(request.toolCallId, ExecutionStatus.FAILED,
                    mapOf("actionAccepted" to true, "textMatched" to false, "snapshot" to observation,
                        "reason" to "输入回读不匹配，请根据当前快照选择后续操作"), emptyList(), ChannelError.EXECUTION_FAILED)
                // A click can legitimately leave the screen unchanged. Return the actual observation;
                // task-goal judgement belongs to the model, not a manual verification form.
                success(request, mapOf("actionAccepted" to true, "observationChanged" to observed, "snapshot" to observation))
            } finally { readbackNode.recycle() }
        } catch (blocked: UiBlocked) {
            val error = if (blocked.reason == "targetChanged") ChannelError.TARGET_CHANGED else ChannelError.UNAVAILABLE
            if (accepted) ExecutionResult(request.toolCallId, ExecutionStatus.FAILED, mapOf("actionAccepted" to true, "reason" to blocked.reason), emptyList(), ChannelError.EXECUTION_FAILED)
            else failure(request, error, blocked.reason, false)
        } catch (_: IllegalArgumentException) {
            failure(request, ChannelError.INVALID_ARGUMENTS, "节点或动作参数无效", accepted)
        } finally {
            if (request.action != ExecutionAction.INSPECT_UI && !accepted) clear()
        }
    }

    private suspend fun gesture(bounds: Rect): Boolean = suspendCancellableCoroutine { continuation ->
        val path = Path().apply { moveTo(bounds.exactCenterX(), bounds.exactCenterY()) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 80)
        val sent = service.dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), object : android.accessibilityservice.AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) { if (continuation.isActive) continuation.resume(true) }
            override fun onCancelled(gestureDescription: GestureDescription?) { if (continuation.isActive) continuation.resume(false) }
        }, null)
        if (!sent && continuation.isActive) continuation.resume(false)
        // Android has no cancellation handle for a dispatched gesture; caller stops waiting without claiming the gesture was undone.
    }

    private fun manual(node: AccessibilityNodeInfo): Boolean {
        if (node.isPassword) return true
        val hint = "${if (android.os.Build.VERSION.SDK_INT >= 26) node.hintText ?: "" else ""} ${node.contentDescription ?: ""}".lowercase()
        if (node.isEditable && listOf("密码", "验证码", "password", "verification code").any(hint::contains)) return true
        return node.isClickable && node.text?.toString() in setOf("确认支付", "立即支付", "付款", "支付")
    }

    companion object {
        private fun success(request: ExecutionRequest, result: Map<String, Any?>) = ExecutionResult(request.toolCallId, ExecutionStatus.SUCCEEDED, result, emptyList())
        private fun failure(request: ExecutionRequest, error: ChannelError, reason: String, accepted: Boolean) = ExecutionResult(request.toolCallId, ExecutionStatus.FAILED, mapOf("reason" to reason, "actionAccepted" to accepted), emptyList(), error)
    }
}

class UiBlocked(val reason: String) : Exception()
