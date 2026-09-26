package app.xiangyue.phase.shizuku

import android.app.UiAutomation
import android.content.Context
import android.os.Bundle
import android.os.SystemClock
import android.text.InputType
import android.view.Display
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive

/** Inserts Unicode into the focused editor on the owned display; never searches the main display. */
internal object DisplayTextInput {
    suspend fun insert(
        context: Context,
        display: Display,
        target: String,
        text: String,
        result: Bundle,
        validate: suspend () -> Unit,
        beforeDispatch: () -> Unit,
    ) {
        if (!display.isValid || display.displayId <= Display.DEFAULT_DISPLAY) throw DisplayTextFault("displayMissing")
        val connection = try { DisplayTextConnection(context, target) }
        catch (_: Exception) { throw DisplayTextFault("textConnectionUnavailable") }
        try {
            val automation = try { connection.open(display) }
            catch (_: Exception) { throw DisplayTextFault("textConnectionUnavailable") }
            validate()
            val node = focusedEditor(automation, display.displayId, target)
            try {
                checkEditor(automation, node, display.displayId, target)
                val original = content(node)
                if (original.length > 16384) throw DisplayTextFault("textFieldTooLarge")
                val start = if (original.isEmpty()) 0 else minOf(node.textSelectionStart, node.textSelectionEnd)
                val end = if (original.isEmpty()) 0 else maxOf(node.textSelectionStart, node.textSelectionEnd)
                if (start !in 0..original.length || end !in start..original.length ||
                    splitsSurrogate(original, start) || splitsSurrogate(original, end)) throw DisplayTextFault("textSelectionUnavailable")
                val expected = original.substring(0, start) + text + original.substring(end)
                if (expected.length > 16384) throw DisplayTextFault("textFieldTooLarge")
                val cursor = start + text.length
                if (cursor != expected.length && !supports(node, AccessibilityNodeInfo.ACTION_SET_SELECTION))
                    throw DisplayTextFault("textSelectionUnavailable")
                validate()
                checkEditor(automation, node, display.displayId, target)
                if (content(node) != original || (original.isNotEmpty() &&
                    (minOf(node.textSelectionStart, node.textSelectionEnd) != start ||
                        maxOf(node.textSelectionStart, node.textSelectionEnd) != end))) throw DisplayTextFault("textTargetChanged")
                beforeDispatch()
                result.putBoolean("actionDispatched", true)
                val accepted = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, expected)
                })
                result.putBoolean("actionAccepted", accepted)
                if (!accepted) throw DisplayTextFault("inputRejected")
                val deadline = SystemClock.uptimeMillis() + 1500
                while (true) {
                    validate()
                    checkEditor(automation, node, display.displayId, target)
                    if (content(node) == expected) break
                    if (SystemClock.uptimeMillis() >= deadline) throw DisplayTextFault("textReadbackMismatch")
                    delay(50)
                }
                if (cursor != expected.length) {
                    validate()
                    checkEditor(automation, node, display.displayId, target)
                    if (content(node) != expected) throw DisplayTextFault("textReadbackMismatch")
                    if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, Bundle().apply {
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, cursor)
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, cursor)
                    })) throw DisplayTextFault("textCursorRejected")
                }
            } finally { node.recycle() }
        } catch (error: CancellationException) { throw error }
        finally {
            if (!connection.close()) result.putString("observationError", "textCleanupFailed")
        }
    }

    private suspend fun focusedEditor(automation: UiAutomation, displayId: Int, target: String): AccessibilityNodeInfo {
        currentCoroutineContext().ensureActive()
        val windows = automation.windowsOnAllDisplays
        try {
            val focused = windows[displayId].orEmpty().filter {
                it.displayId == displayId && it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isFocused
            }
            if (focused.size != 1) throw DisplayTextFault("textFocusMissing")
            val window = focused.single()
            val root = window.root ?: throw DisplayTextFault("textFocusMissing")
            try {
                if (root.packageName?.toString() != target) throw DisplayTextFault("textTargetChanged")
                return root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: throw DisplayTextFault("textFocusMissing")
            } finally { root.recycle() }
        } finally {
            for (index in 0 until windows.size()) windows.valueAt(index).forEach { it.recycle() }
        }
    }

    private fun checkEditor(automation: UiAutomation, node: AccessibilityNodeInfo, displayId: Int, target: String) {
        if (!automation.clearCache()) throw DisplayTextFault("textConnectionUnavailable")
        if (!node.refresh() || node.packageName?.toString() != target || !node.isFocused ||
            !node.isVisibleToUser || !node.isEnabled) throw DisplayTextFault("textTargetChanged")
        val window = node.window ?: throw DisplayTextFault("textTargetChanged")
        try {
            if (window.displayId != displayId || !window.isFocused || window.type != AccessibilityWindowInfo.TYPE_APPLICATION)
                throw DisplayTextFault("textTargetChanged")
        } finally { window.recycle() }
        if (sensitive(node)) throw DisplayTextFault("textRequiresManual")
        if (!node.isEditable || !supports(node, AccessibilityNodeInfo.ACTION_SET_TEXT)) throw DisplayTextFault("textUnsupported")
    }

    private fun sensitive(node: AccessibilityNodeInfo): Boolean {
        val inputClass = node.inputType and InputType.TYPE_MASK_CLASS
        val variation = node.inputType and InputType.TYPE_MASK_VARIATION
        if (node.isPassword ||
            (inputClass == InputType.TYPE_CLASS_TEXT && variation in setOf(InputType.TYPE_TEXT_VARIATION_PASSWORD,
                InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD, InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD)) ||
            (inputClass == InputType.TYPE_CLASS_NUMBER && variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD)) return true
        val hint = "${node.hintText?.toString().orEmpty()} ${node.contentDescription?.toString().orEmpty()}".lowercase()
        return listOf("密码", "验证码", "password", "verification code", "one-time", "otp").any(hint::contains)
    }

    private fun content(node: AccessibilityNodeInfo) = if (node.isShowingHintText) "" else node.text?.toString().orEmpty()
    private fun supports(node: AccessibilityNodeInfo, action: Int) = node.actionList.any { it.id == action }
    private fun splitsSurrogate(text: String, index: Int) = index in 1 until text.length &&
        Character.isHighSurrogate(text[index - 1]) && Character.isLowSurrogate(text[index])
}
