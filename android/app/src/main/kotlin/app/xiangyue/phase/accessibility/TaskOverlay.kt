package app.xiangyue.phase.accessibility

import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.AnimationSet
import android.view.animation.PathInterpolator
import android.view.animation.TranslateAnimation
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.*
import app.xiangyue.phase.R
import app.xiangyue.phase.bridge.*
import kotlinx.coroutines.CompletableDeferred
import org.json.JSONObject

/** A bottom composer with a bounded touch region; never cover the rest of the display. */
class TaskOverlay(private val service: PhaseAccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val keyboard = service.getSystemService(InputMethodManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val easing = PathInterpolator(0.2f, 0f, 0f, 1f)
    private var view: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var motion: ValueAnimator? = null
    private var targetFrame: TaskPanelFrame? = null
    private var run: String? = null
    private var finished = false
    private var submitting = false
    private var snapshot: TaskPanelSnapshot? = null
    private var confirmation: ExecutionConfirmation? = null
    private var continuing = false
    private var darkOverride: Boolean? = null
    private var column: LinearLayout? = null
    private var title: TaskPanelTextView? = null
    private var displayedHeadline: TaskPanelHeadline? = null
    private var lastAiHeadline: TaskPanelHeadline? = null
    private var continueButton: ImageButton? = null
    private var closeButton: ImageButton? = null
    private var primaryButton: PanelButton? = null
    private var editor: OverlayEditText? = null
    private var errorView: TextView? = null
    private var approval: LinearLayout? = null
    private var approvalLabel: TextView? = null
    private var approvalBody: TextView? = null
    private var allowButton: TextView? = null
    private var countdown: Runnable? = null
    private var draft = ""
    private var selectionStart = 0
    private var selectionEnd = 0
    private var inputError: String? = null
    private var editing: CompletableDeferred<Unit>? = null
    private var imeBottom = 0
    private var imeVisible = false
    private var detaching = false
    private var surfaceKey: Int? = null
    private var decide: (ConfirmationDecision) -> Unit = {}
    private var stop: () -> Unit = {}
    private var resume: (String) -> Unit = {}
    private var send: (String) -> Unit = {}
    private var open: () -> Unit = {}
    private var close: () -> Unit = {}
    private val dark get() = darkOverride ?: (service.resources.configuration.uiMode and
        Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES)
    private val ink get() = color(if (dark) "#E4EAF7" else "#182338")
    private val muted get() = color(if (dark) "#BAC6DC" else "#475469")
    private val accent get() = color(if (dark) "#BACBFF" else "#3D5A98")
    private val onAccent get() = color(if (dark) "#1C2E52" else "#FFFFFF")
    private val error get() = color(if (dark) "#FFB4AB" else "#B3261E")
    private val waiting get() = !finished && snapshot?.waitingToolCallId != null

    /** A user editing the panel owns keyboard focus; queued device actions wait before dispatch. */
    suspend fun awaitInputIdle() { while (editing != null) editing?.await() }

    /** Capture, locking and lifecycle hides are immediate. Only a draft and two-line preview survive. */
    fun hide() {
        detaching = true
        editor?.let {
            draft = it.text.toString()
            selectionStart = it.selectionStart.coerceAtLeast(0)
            selectionEnd = it.selectionEnd.coerceAtLeast(0)
        }
        finishEditing()
        countdown?.let(handler::removeCallbacks); countdown = null
        motion?.cancel(); motion = null; targetFrame = null
        title?.clearAnimation()
        primaryButton?.face?.animate()?.cancel()
        view?.let { try { manager.removeView(it) } catch (_: IllegalArgumentException) {} }
        view = null; params = null; column = null; title = null; displayedHeadline = null
        continueButton = null; closeButton = null; primaryButton = null
        editor = null; errorView = null; approval = null; approvalLabel = null; approvalBody = null; allowButton = null
        imeBottom = 0; imeVisible = false
        decide = {}; stop = {}; resume = {}; send = {}; open = {}; close = {}
        detaching = false
    }

    fun show(
        runId: String, value: TaskPanelSnapshot?, pending: ExecutionConfirmation?, finished: Boolean,
        isContinuing: Boolean, isSubmitting: Boolean, decide: (ConfirmationDecision) -> Unit,
        stop: () -> Unit, resume: (String) -> Unit, send: (String) -> Unit,
        open: () -> Unit, close: () -> Unit,
    ) {
        val wasDark = dark
        if (run != runId) {
            hide(); run = runId; lastAiHeadline = null
            if (!isSubmitting) { draft = ""; selectionStart = 0; selectionEnd = 0; inputError = null; darkOverride = null }
        }
        if (value != null) darkOverride = value.darkTheme
        if (view != null && wasDark != dark) hide()
        snapshot = value; confirmation = pending; continuing = isContinuing
        this.finished = finished; submitting = isSubmitting
        this.decide = decide; this.stop = stop; this.resume = resume
        this.send = send; this.open = open; this.close = close
        if (view == null) attach() else render(animate = true)
        countdown?.let(handler::removeCallbacks); countdown = null
        if (pending != null) {
            countdown = object : Runnable {
                override fun run() { render(animate = false); handler.postDelayed(this, 1000) }
            }.also { handler.postDelayed(it, 1000) }
        }
    }

    fun inputFinished(text: String, error: String?) {
        submitting = false
        inputError = error
        if (error == null && draft == text) {
            draft = ""; selectionStart = 0; selectionEnd = 0
            editor?.setText("")
        }
        render(animate = true)
    }

    fun dismiss() {
        hide(); run = null; snapshot = null; confirmation = null; lastAiHeadline = null
        draft = ""; selectionStart = 0; selectionEnd = 0; inputError = null; darkOverride = null
    }

    private fun attach() {
        val root = FrameLayout(service).apply {
            setPadding(dp(12), dp(12), dp(12), dp(4))
            elevation = dp(6).toFloat(); clipToOutline = true
            setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_OUTSIDE) finishEditing()
                false
            }
        }
        view = root
        val content = LinearLayout(service).apply { orientation = LinearLayout.VERTICAL }
        column = content
        val preview = LinearLayout(service).apply { gravity = Gravity.CENTER_VERTICAL }
        title = TaskPanelTextView(service).apply {
            textSize = 14f; minLines = 2; minimumHeight = dp(48)
            setLineSpacing(0f, 1.5f); setPadding(dp(4), 0, dp(4), 0)
            setOnClickListener { finishEditing(); open() }
        }
        preview.addView(title, LinearLayout.LayoutParams(0, -2, 1f))
        continueButton = icon(R.drawable.ic_task_play, "继续，让 AI 接管", accent) {
            snapshot?.waitingToolCallId?.let { if (!continuing) { finishEditing(); resume(it) } }
        }
        preview.addView(continueButton)
        preview.addView(icon(R.drawable.ic_task_return, "返回相月", muted) { finishEditing(); open() })
        closeButton = icon(R.drawable.ic_task_close, "关闭悬浮窗", muted) { finishEditing(); close() }
        preview.addView(closeButton)
        content.addView(preview)
        approval = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(4), dp(8), dp(4), dp(4))
        }
        approvalLabel = text(12f, accent)
        approvalBody = text(14f, ink).apply { setPadding(0, dp(4), 0, dp(4)); setTextIsSelectable(true) }
        approval!!.addView(approvalLabel)
        approval!!.addView(ScrollView(service).apply { addView(approvalBody) }, LinearLayout.LayoutParams(-1, dp(136)))
        val decisions = LinearLayout(service).apply { gravity = Gravity.END or Gravity.CENTER_VERTICAL }
        decisions.addView(action("拒绝", muted, Color.TRANSPARENT) { decide(ConfirmationDecision.REJECT) },
            LinearLayout.LayoutParams(0, -2, 1f))
        allowButton = action("允许一次", onAccent, accent) { decide(ConfirmationDecision.APPROVE) }
        decisions.addView(allowButton, LinearLayout.LayoutParams(0, -2, 2f))
        approval!!.addView(decisions)
        content.addView(approval)
        val inputRow = LinearLayout(service).apply {
            gravity = Gravity.CENTER_VERTICAL; minimumHeight = dp(56)
        }
        editor = OverlayEditText(service) { finishEditing() }.apply {
            textSize = 16f; setTextColor(ink); setHintTextColor(muted)
            highlightColor = Color.argb(if (dark) 71 else 46, Color.red(accent), Color.green(accent), Color.blue(accent))
            if (Build.VERSION.SDK_INT >= 29) textCursorDrawable = GradientDrawable().apply {
                setColor(accent); setSize(dp(2), lineHeight); cornerRadius = dp(1).toFloat()
            }
            hint = "输入消息…"; background = null
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_NONE or EditorInfo.IME_FLAG_NO_EXTRACT_UI
            minLines = 1; maxLines = 2; minimumHeight = dp(48)
            setLineSpacing(0f, 1.5f); setPadding(dp(4), dp(4), dp(4), dp(4))
            filters = arrayOf(InputFilter.LengthFilter(16000))
            setText(draft)
            setSelection(selectionStart.coerceIn(0, text.length), selectionEnd.coerceIn(0, text.length))
            setOnTouchListener { _, event -> if (event.actionMasked == MotionEvent.ACTION_DOWN) startEditing(); false }
            onFocusChangeListener = View.OnFocusChangeListener { _, focused ->
                if (focused) startEditing() else finishEditing()
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    draft = s?.toString().orEmpty(); inputError = null
                    render(animate = true)
                }
                override fun afterTextChanged(s: Editable?) {}
            })
        }
        inputRow.addView(editor, LinearLayout.LayoutParams(0, -2, 1f))
        primaryButton = panelButton(R.drawable.ic_task_send, "发送", onAccent, accent) {
            if (!finished || submitting) { stop(); finishEditing() } else submit()
        }
        inputRow.addView(primaryButton!!.container)
        content.addView(inputRow)
        errorView = text(12f, error).apply { setPadding(dp(4), 0, dp(4), dp(8)); accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE }
        content.addView(errorView)
        // Short landscape/large-font layouts scroll instead of reducing text or action touch targets.
        root.addView(ScrollView(service).apply { isFillViewport = false; addView(content) }, FrameLayout.LayoutParams(-1, -2))
        params = WindowManager.LayoutParams(
            dp(328), dp(124), WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            softInputMode = if (Build.VERSION.SDK_INT >= 30) WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
                else WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            if (Build.VERSION.SDK_INT >= 30) setFitInsetsTypes(0)
        }
        if (Build.VERSION.SDK_INT >= 30) {
            root.setOnApplyWindowInsetsListener { _, insets -> updateInsets(insets); insets }
            root.setWindowInsetsAnimationCallback(object : WindowInsetsAnimation.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                override fun onProgress(insets: WindowInsets, runningAnimations: MutableList<WindowInsetsAnimation>): WindowInsets {
                    updateInsets(insets)
                    return insets
                }
            })
        } else {
            root.viewTreeObserver.addOnGlobalLayoutListener {
                if (view !== root) return@addOnGlobalLayoutListener
                val visibleFrame = Rect().also(root::getWindowVisibleDisplayFrame)
                val metrics = DisplayMetrics().also { manager.defaultDisplay.getRealMetrics(it) }
                val covered = (metrics.heightPixels - visibleFrame.bottom).coerceAtLeast(0)
                updateKeyboardInset(if (covered > dp(120)) covered else 0, covered > dp(120))
            }
        }
        render(animate = false)
        manager.addView(root, params)
        root.requestApplyInsets()
    }

    private fun render(animate: Boolean) {
        if (view == null) return
        val latest = snapshot?.messages?.lastOrNull { it.kind != TaskPanelMessageKind.TOOL && it.text.isNotBlank() }
        if (latest != null) lastAiHeadline = TaskPanelHeadline(latest.text, latest.id)
        val headline = when {
            waiting -> TaskPanelHeadline(snapshot?.userPrompt ?: "等待你操作", "user/${snapshot?.waitingToolCallId}")
            lastAiHeadline != null -> lastAiHeadline!!
            submitting -> TaskPanelHeadline("正在发送消息")
            finished -> TaskPanelHeadline("任务已结束")
            else -> TaskPanelHeadline(snapshot?.status ?: "正在处理")
        }
        if (displayedHeadline != headline) {
            val sameResponse = headline.responseId != null && headline.responseId == displayedHeadline?.responseId
            title?.apply {
                setTypeface(Typeface.DEFAULT, Typeface.NORMAL)
                setTextColor(if (headline.responseId == null) muted else ink)
                showHeadline(headline)
                contentDescription = "${headline.text}。返回相月"
                if (!sameResponse) {
                    clearAnimation()
                    val duration = if (animate && displayedHeadline != null) motionDuration(150) else 0L
                    if (duration > 0) startAnimation(textMotion(duration))
                }
            }
            displayedHeadline = headline
        }
        continueButton?.apply {
            visibility = if (waiting) View.VISIBLE else View.GONE
            isEnabled = !continuing && !submitting
            alpha = if (isEnabled) 1f else 0.4f
        }
        closeButton?.visibility = if (finished && !submitting) View.VISIBLE else View.GONE
        val active = !finished || submitting
        primaryButton?.apply {
            val resource = if (active) R.drawable.ic_task_stop else R.drawable.ic_task_send
            if (image.tag != resource) { image.setImageResource(resource); image.tag = resource }
            val label = if (active) "打断任务" else "发送"
            container.contentDescription = label
            if (Build.VERSION.SDK_INT >= 26) container.tooltipText = label
            setEnabled(active || draft.isNotBlank())
        }
        editor?.isEnabled = !submitting
        errorView?.apply { text = inputError; visibility = if (inputError == null) View.GONE else View.VISIBLE }
        val pending = confirmation
        approval?.visibility = if (pending != null && !finished) View.VISIBLE else View.GONE
        if (pending != null) {
            val seconds = ((pending.expiresAtMs - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            val scope = if (pending.applicationOperationsForRun) "本轮应用操作" else "本次动作"
            approvalLabel?.text = "确认$scope · $seconds 秒"
            val detail = "${pending.summary}\n目标：${pending.targetLabel ?: "选定 App"}\n执行通道：Android\n${JSONObject(pending.arguments).toString(2)}"
            if (approvalBody?.text?.toString() != detail) approvalBody?.text = detail
            allowButton?.text = if (pending.applicationOperationsForRun) "允许本轮操作应用" else "允许一次"
        }
        updateSurface()
        place(animate)
    }

    private fun submit() {
        if (!finished || submitting || draft.isBlank()) return
        val text = draft
        inputError = null
        // Native cancellation is latched before releasing focus to any queued device action.
        send(text)
        finishEditing()
    }

    private fun startEditing() {
        val input = editor ?: return
        val root = view ?: return
        val layout = params ?: return
        if (submitting || editing != null || detaching) return
        editing = CompletableDeferred()
        layout.flags = layout.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
        if (root.isAttachedToWindow) manager.updateViewLayout(root, layout)
        input.requestFocus()
        input.post { if (editor === input && editing != null) keyboard.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT) }
        updateSurface()
    }

    private fun finishEditing() {
        val pending = editing ?: return
        editing = null
        editor?.let { keyboard.hideSoftInputFromWindow(it.windowToken, 0); it.clearFocus() }
        params?.let { layout ->
            layout.flags = layout.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            view?.takeIf { it.isAttachedToWindow }?.let { manager.updateViewLayout(it, layout) }
        }
        pending.complete(Unit)
        if (!detaching) updateSurface()
    }

    private fun updateInsets(insets: WindowInsets) {
        if (Build.VERSION.SDK_INT < 30) return
        val bottom = insets.getInsets(WindowInsets.Type.ime()).bottom
        val visible = insets.isVisible(WindowInsets.Type.ime())
        updateKeyboardInset(bottom, visible)
    }

    private fun updateKeyboardInset(bottom: Int, visible: Boolean) {
        val dismissed = imeVisible && !visible
        imeVisible = visible
        if (bottom != imeBottom) { imeBottom = bottom; place(animate = false) }
        if (dismissed) finishEditing()
    }

    private fun place(animate: Boolean) {
        val area = safeArea()
        val width = minOf(dp(840), area.width()).coerceAtLeast(1)
        val content = column ?: return
        content.measure(exact((width - dp(24)).coerceAtLeast(1)), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        val height = (content.measuredHeight + dp(16)).coerceAtMost(area.height()).coerceAtLeast(1)
        val target = TaskPanelFrame(area.left + (area.width() - width) / 2, area.bottom - height, width, height)
        if (target != targetFrame || !animate) moveTo(target, animate)
    }

    private fun moveTo(target: TaskPanelFrame, animate: Boolean) {
        val root = view ?: return
        val layout = params ?: return
        motion?.cancel(); motion = null; targetFrame = target
        val start = TaskPanelFrame(layout.x, layout.y, layout.width, layout.height)
        fun apply(progress: Float) {
            if (view !== root) return
            val frame = start.towards(target, progress)
            layout.x = frame.x; layout.y = frame.y; layout.width = frame.width; layout.height = frame.height
            if (root.isAttachedToWindow) manager.updateViewLayout(root, layout)
        }
        val duration = if (animate) motionDuration(220) else 0L
        if (duration == 0L) { apply(1f); return }
        motion = ValueAnimator.ofFloat(0f, 1f).apply {
            this.duration = duration; interpolator = easing
            addUpdateListener { apply(it.animatedValue as Float) }
            start()
        }
    }

    private fun updateSurface() {
        val root = view ?: return
        val reduced = motionDuration(1) == 0L
        val key = (if (dark) 1 else 0) or (if (editing != null) 2 else 0) or (if (reduced) 4 else 0)
        if (root.background != null && surfaceKey == key) return
        surfaceKey = key
        root.background = GradientDrawable(GradientDrawable.Orientation.TL_BR, when {
            reduced -> intArrayOf(color(if (dark) "#101B2B" else "#F5F7FC"), color(if (dark) "#101B2B" else "#F5F7FC"))
            dark -> intArrayOf(color("#F2101B2B"), color("#F219263D"))
            else -> intArrayOf(color("#F2FFFFFF"), color("#F2F0F3FA"))
        }).apply {
            cornerRadius = dp(28).toFloat()
            setStroke(dp(1), if (editing != null) accent else color(if (dark) "#29E4EAF7" else "#A3FFFFFF"))
        }
    }

    private fun safeArea(): Rect {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = manager.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            return Rect(metrics.bounds).apply {
                left += insets.left + dp(16); top += insets.top + dp(8)
                right -= insets.right + dp(16); bottom -= maxOf(insets.bottom, imeBottom) + dp(4)
                bottom = bottom.coerceAtLeast(top + 1)
            }
        }
        val metrics = DisplayMetrics().also { manager.defaultDisplay.getRealMetrics(it) }
        return Rect(dp(16), dp(32), metrics.widthPixels - dp(16),
            (metrics.heightPixels - maxOf(dp(48), imeBottom) - dp(4)).coerceAtLeast(dp(32) + 1))
    }

    private fun panelButton(resource: Int, label: String, ink: Int, fill: Int, action: () -> Unit): PanelButton {
        val container = FrameLayout(service).apply {
            layoutParams = LinearLayout.LayoutParams(dp(56), dp(56))
            contentDescription = label; isFocusable = true
            if (Build.VERSION.SDK_INT >= 26) tooltipText = label
            setOnClickListener { action() }
        }
        val image = ImageView(service).apply { setImageResource(resource); imageTintList = ColorStateList.valueOf(ink); tag = resource }
        val face = FrameLayout(service).apply {
            background = ripple(fill); isDuplicateParentStateEnabled = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            addView(image, FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER))
        }
        container.addView(face, FrameLayout.LayoutParams(dp(40), dp(40), Gravity.CENTER))
        container.setOnTouchListener { _, event ->
            if (container.isEnabled && motionDuration(120) > 0) {
                val scale = if (event.actionMasked == MotionEvent.ACTION_DOWN) 0.92f else 1f
                if (event.actionMasked in setOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL))
                    face.animate().scaleX(scale).scaleY(scale).setDuration(120).setInterpolator(easing).start()
            }
            false
        }
        return PanelButton(container, face, image)
    }

    private fun action(label: String, ink: Int, fill: Int, action: () -> Unit) = text(14f, ink).apply {
        text = label; gravity = Gravity.CENTER; minimumHeight = dp(48)
        setPadding(dp(16), 0, dp(16), 0); background = ripple(fill)
        isFocusable = true; setOnClickListener { action() }
    }

    private fun icon(resource: Int, label: String, ink: Int, action: () -> Unit) = ImageButton(service).apply {
        setImageResource(resource); imageTintList = ColorStateList.valueOf(ink)
        setPadding(dp(12), dp(12), dp(12), dp(12)); background = ripple(Color.TRANSPARENT)
        contentDescription = label
        if (Build.VERSION.SDK_INT >= 26) tooltipText = label
        layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
        setOnClickListener { action() }
    }
    private fun motionDuration(value: Long): Long {
        val enabled = if (Build.VERSION.SDK_INT >= 26) ValueAnimator.areAnimatorsEnabled()
        else Settings.Global.getFloat(service.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f
        return if (enabled) value else 0L
    }
    private fun textMotion(duration: Long) = AnimationSet(false).apply {
        addAnimation(AlphaAnimation(0f, 1f)); addAnimation(TranslateAnimation(0f, 0f, dp(4).toFloat(), 0f))
        this.duration = duration; interpolator = easing
    }
    private fun text(size: Float, ink: Int) = TextView(service).apply { textSize = size; setTextColor(ink) }
    private fun exact(value: Int) = View.MeasureSpec.makeMeasureSpec(value, View.MeasureSpec.EXACTLY)
    private fun ripple(fill: Int) = RippleDrawable(ColorStateList.valueOf(color(if (dark) "#334F6BA5" else "#223D5A98")), shape(fill), shape(Color.WHITE))
    private fun shape(fill: Int) = GradientDrawable().apply { setColor(fill); cornerRadius = dp(20).toFloat() }
    private fun dp(value: Int) = (value * service.resources.displayMetrics.density).toInt()
    private fun color(value: String) = Color.parseColor(value)
    private data class PanelButton(val container: FrameLayout, val face: FrameLayout, val image: ImageView) {
        fun setEnabled(value: Boolean) {
            container.isEnabled = value; container.alpha = if (value) 1f else 0.38f
            if (!value) { face.animate().cancel(); face.scaleX = 1f; face.scaleY = 1f }
        }
    }
    private class OverlayEditText(context: Context, private val dismiss: () -> Unit) : EditText(context) {
        override fun onKeyPreIme(keyCode: Int, event: KeyEvent?): Boolean {
            if (keyCode == KeyEvent.KEYCODE_BACK && hasFocus()) {
                if (event?.action == KeyEvent.ACTION_UP && !event.isCanceled) dismiss()
                return true
            }
            return super.onKeyPreIme(keyCode, event)
        }
    }
}
