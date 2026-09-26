package app.xiangyue.phase.accessibility

import android.animation.ValueAnimator
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
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewTreeObserver
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.AnimationSet
import android.view.animation.PathInterpolator
import android.view.animation.TranslateAnimation
import android.widget.*
import app.xiangyue.phase.R
import app.xiangyue.phase.bridge.*
import org.json.JSONObject
import kotlin.math.abs

/** A single, bounded window: morph its bounds rather than remove/re-add it on every state change. */
class TaskOverlay(private val service: PhaseAccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val position = TaskPanelPosition()
    private val easing = PathInterpolator(0.2f, 0f, 0f, 1f)
    private var view: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var motion: ValueAnimator? = null
    private var targetFrame: TaskPanelFrame? = null
    private var run: String? = null
    private var expanded = false
    private var finished = false
    private var snapshot: TaskPanelSnapshot? = null
    private var confirmation: ExecutionConfirmation? = null
    private var continuing = false
    private var column: LinearLayout? = null
    private var header: LinearLayout? = null
    private var title: TaskPanelTextView? = null
    private var displayedHeadline: TaskPanelHeadline? = null
    private var chevron: ImageView? = null
    private var primary: ImageButton? = null
    private var stopButton: ImageButton? = null
    private var footer: LinearLayout? = null
    private var terminal: LinearLayout? = null
    private var scroll: ScrollView? = null
    private var feed: LinearLayout? = null
    private val rows = linkedMapOf<String, MessageRow>()
    private var scrollY = 0
    private var followTail = true
    private var reading = false
    private var followOnLayout: ViewTreeObserver.OnPreDrawListener? = null
    private var countdown: Runnable? = null
    private var decide: (ConfirmationDecision) -> Unit = {}
    private var stop: () -> Unit = {}
    private var resume: (String) -> Unit = {}
    private var open: () -> Unit = {}
    private var close: () -> Unit = {}
    private var dragX = 0f
    private var dragY = 0f
    private var originX = 0
    private var originY = 0
    private var dragging = false
    private val dark get() = service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    private val ink get() = color(if (dark) "#E5EBF7" else "#17243D")
    private val muted get() = color(if (dark) "#BBC6DC" else "#4C5E7C")
    private val accent get() = color(if (dark) "#BACBFF" else "#3D5A98")
    private val error get() = color(if (dark) "#FFB4AB" else "#B3261E")
    private val surface get() = color(if (dark) "#F019263D" else "#F7F5F7FC")
    private val waiting get() = snapshot?.waitingToolCallId != null

    /** Capture and lifecycle hides are immediate; no animation may leak into a tool screenshot. */
    fun hide() {
        countdown?.let(handler::removeCallbacks); countdown = null
        motion?.cancel(); motion = null; targetFrame = null
        scroll?.let { scrollY = it.scrollY; followTail = !it.canScrollVertically(1) }
        title?.clearAnimation()
        rows.values.forEach { it.container.animate().cancel() }
        followOnLayout?.let { listener ->
            view?.viewTreeObserver?.takeIf { it.isAlive }?.removeOnPreDrawListener(listener)
        }
        followOnLayout = null
        view?.let { try { manager.removeView(it) } catch (_: IllegalArgumentException) {} }
        view = null; params = null; column = null; header = null; title = null
        chevron = null; primary = null; stopButton = null; footer = null; terminal = null
        scroll = null; feed = null; rows.clear(); displayedHeadline = null; reading = false
        decide = {}; stop = {}; resume = {}; open = {}; close = {}
    }

    fun show(
        runId: String, value: TaskPanelSnapshot?, pending: ExecutionConfirmation?, finished: Boolean,
        isContinuing: Boolean, decide: (ConfirmationDecision) -> Unit, stop: () -> Unit,
        resume: (String) -> Unit, open: () -> Unit, close: () -> Unit,
    ) {
        if (run != runId) {
            hide(); run = runId; expanded = false; scrollY = 0; followTail = true
        }
        val newConfirmation = pending != null && confirmation?.toolCallId != pending.toolCallId
        if (newConfirmation) expanded = true
        snapshot = value; confirmation = pending; continuing = isContinuing; this.finished = finished
        this.decide = decide; this.stop = stop; this.resume = resume; this.open = open; this.close = close
        if (view == null) attach() else render(animate = true)
        countdown?.let(handler::removeCallbacks); countdown = null
        if (pending != null) {
            countdown = object : Runnable {
                override fun run() { render(animate = true); handler.postDelayed(this, 1000) }
            }.also { handler.postDelayed(it, 1000) }
        }
    }

    private fun attach() {
        val root = FrameLayout(service).apply {
            background = shape(surface, 24).apply { setStroke(dp(1), color(if (dark) "#425472" else "#D8E1F3")) }
            elevation = dp(6).toFloat()
            clipToOutline = true
        }
        view = root
        column = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        val row = LinearLayout(service).apply { gravity = Gravity.CENTER_VERTICAL; minimumHeight = dp(56) }
        header = row
        column!!.addView(row)
        val toggle = LinearLayout(service).apply {
            gravity = Gravity.CENTER_VERTICAL; minimumHeight = dp(56)
            setPadding(dp(8), 0, 0, 0); background = ripple(Color.TRANSPARENT)
            setOnClickListener { expanded = !expanded; render(animate = true) }
        }
        title = TaskPanelTextView(service).apply { textSize = 14f; setTextColor(accent) }
        toggle.addView(title, LinearLayout.LayoutParams(0, -2, 1f))
        chevron = ImageView(service).apply {
            setImageResource(R.drawable.ic_task_expand); imageTintList = ColorStateList.valueOf(muted)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        toggle.addView(chevron, LinearLayout.LayoutParams(dp(16), dp(24)))
        draggable(toggle)
        row.addView(toggle, LinearLayout.LayoutParams(0, -2, 1f))
        primary = icon(R.drawable.ic_task_stop, "停止任务", error) {
            val callId = snapshot?.waitingToolCallId
            if (callId != null) { if (!continuing) resume(callId) } else stop()
        }
        row.addView(primary)
        stopButton = icon(R.drawable.ic_task_stop, "停止任务", error) { stop() }
        row.addView(stopButton)
        feed = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), 0, dp(12), dp(8))
        }
        scroll = ScrollView(service).apply {
            isFillViewport = false; addView(feed)
            setOnTouchListener { _, event ->
                reading = event.actionMasked != MotionEvent.ACTION_UP && event.actionMasked != MotionEvent.ACTION_CANCEL
                followTail = !canScrollVertically(1); this@TaskOverlay.scrollY = this.scrollY
                false
            }
        }
        column!!.addView(scroll, LinearLayout.LayoutParams(-1, dp(136)))
        footer = LinearLayout(service).apply { gravity = Gravity.END }
        footer!!.addView(icon(R.drawable.ic_task_close, "拒绝本次动作", muted) { decide(ConfirmationDecision.REJECT) })
        footer!!.addView(icon(R.drawable.ic_task_check, "允许本次动作", accent) { decide(ConfirmationDecision.APPROVE) })
        column!!.addView(footer)
        root.addView(column, FrameLayout.LayoutParams(-1, -2))
        terminal = LinearLayout(service).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(4), dp(4), dp(4), dp(4)); minimumHeight = dp(64)
            addView(icon(R.drawable.ic_task_return, "返回相月", accent) { open() }.also(::draggable))
            addView(icon(R.drawable.ic_task_close, "关闭悬浮窗", muted) { close() }.also(::draggable))
        }
        root.addView(terminal, FrameLayout.LayoutParams(-1, -2))
        params = WindowManager.LayoutParams(
            dp(168), dp(64), WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.LEFT }
        render(animate = false)
        manager.addView(root, params)
    }

    private fun render(animate: Boolean) {
        val root = view ?: return
        val pending = confirmation
        val headline = if (finished) displayedHeadline ?: TaskPanelHeadline("") else
            TaskPanelHeadline.from(snapshot, expanded, pending != null, continuing)
        if (displayedHeadline != headline) {
            // Stream increments replace text in place; only a new message/stage animates.
            val sameResponse = headline.responseId != null && headline.responseId == displayedHeadline?.responseId
            val duration = if (animate && displayedHeadline != null && !sameResponse) motionDuration(150) else 0L
            title?.apply {
                setTypeface(Typeface.DEFAULT, if (headline.responseId == null) Typeface.BOLD else Typeface.NORMAL)
                setTextColor(if (headline.responseId == null) accent else ink)
                showHeadline(headline)
                if (!sameResponse) {
                    clearAnimation()
                    if (duration > 0) startAnimation(textMotion(duration))
                }
            }
            displayedHeadline = headline
        }
        (header?.getChildAt(0))?.contentDescription = "${headline.text}。${if (expanded) "收起" else "展开"}任务面板；可拖动到屏幕两侧"
        primary?.apply {
            setImageResource(if (waiting) R.drawable.ic_task_play else R.drawable.ic_task_stop)
            imageTintList = ColorStateList.valueOf(if (waiting) accent else error)
            contentDescription = if (waiting) "继续，让 AI 接管" else "停止任务"
            if (Build.VERSION.SDK_INT >= 26) tooltipText = contentDescription
            isEnabled = !waiting || !continuing
            alpha = if (isEnabled) 1f else 0.4f
        }
        // A single action in the narrow capsule. Expanded handoff keeps both Continue and Stop.
        stopButton?.visibility = if (waiting && expanded) View.VISIBLE else View.GONE
        footer?.visibility = if (pending != null) View.VISIBLE else View.GONE
        footer?.getChildAt(1)?.apply {
            contentDescription = if (pending?.applicationOperationsForRun == true)
                "允许本轮操作应用" else "允许本次动作"
            if (Build.VERSION.SDK_INT >= 26) tooltipText = contentDescription
        }
        column?.visibility = View.VISIBLE
        column?.importantForAccessibility = if (finished) View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS else View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        terminal?.visibility = if (finished) View.VISIBLE else View.GONE
        scroll?.importantForAccessibility = if (expanded && !finished) View.IMPORTANT_FOR_ACCESSIBILITY_AUTO else View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        footer?.importantForAccessibility = if (expanded && !finished) View.IMPORTANT_FOR_ACCESSIBILITY_AUTO else View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        updateMessages(animate && expanded && !finished)
        val area = safeArea()
        val width = minOf(dp(if (finished) 104 else if (expanded) 264 else 168), area.width())
        header!!.measure(exact(width - dp(8)), View.MeasureSpec.makeMeasureSpec(area.height(), View.MeasureSpec.AT_MOST))
        val headingHeight = header!!.measuredHeight + dp(8)
        val footerHeight = if (pending != null) dp(48) else 0
        val bodyHeight = minOf(dp(136), (area.height() - headingHeight - footerHeight).coerceAtLeast(0))
        scroll?.layoutParams = LinearLayout.LayoutParams(-1, bodyHeight)
        val height = if (finished) dp(64) else headingHeight + if (expanded) bodyHeight + footerHeight else 0
        val (x, y) = position.place(area.width(), area.height(), width, height)
        val target = TaskPanelFrame(area.left + x, area.top + y, width, height)
        if (!dragging && (target != targetFrame || !animate)) moveTo(target, animate)
        followAfterLayout(root)
    }

    private fun followAfterLayout(root: View) {
        if (followOnLayout != null) return
        val listener = object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (root.viewTreeObserver.isAlive) root.viewTreeObserver.removeOnPreDrawListener(this)
                followOnLayout = null
                val viewport = scroll
                if (view === root && viewport != null && !reading) {
                    // Wait for text reflow; scrolling before layout can mistake new content for manual review.
                    val y = if (followTail) ((feed?.height ?: 0) - viewport.height).coerceAtLeast(0) else scrollY
                    viewport.scrollTo(0, y)
                }
                return true
            }
        }
        followOnLayout = listener
        root.viewTreeObserver.addOnPreDrawListener(listener)
        root.invalidate()
    }

    private fun updateMessages(animate: Boolean) {
        val list = feed ?: return
        val viewport = scroll ?: return
        if (viewport.isLaidOut && !reading && followOnLayout == null) {
            followTail = !viewport.canScrollVertically(1)
            scrollY = viewport.scrollY
        }
        val messages = if (finished) emptyList() else snapshot?.messages.orEmpty()
        val items = messages.toMutableList()
        val pending = confirmation
        if (pending != null) {
            val seconds = ((pending.expiresAtMs - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            val scope = if (pending.applicationOperationsForRun) "本轮应用操作" else "本次动作"
            items.add(TaskPanelMessage("confirmation/${pending.toolCallId}", TaskPanelMessageKind.TOOL,
                "确认$scope · $seconds 秒", "${pending.summary}\n目标：${pending.targetLabel ?: "选定 App"}\n执行通道：Android\n${JSONObject(pending.arguments).toString(2)}"))
        } else if (waiting) {
            val id = "tool/${snapshot?.waitingToolCallId}"
            val request = TaskPanelMessage(id, TaskPanelMessageKind.TOOL, "请你操作",
                "${snapshot?.userPrompt}\n完成后点击继续，AI 再接管。")
            val index = items.indexOfFirst { it.id == id }
            if (index < 0) items.add(request) else items[index] = request
        }
        if (items.size > 6) items.subList(0, items.size - 6).clear()
        val keep = items.map { it.id }.toSet()
        for (id in rows.keys.toList()) {
            if (id in keep) continue
            val removed = rows.remove(id)!!
            if (!followTail && removed.container.top < viewport.scrollY) scrollY = (scrollY - removed.container.height).coerceAtLeast(0)
            removed.container.animate().cancel(); list.removeView(removed.container)
        }
        for ((index, item) in items.withIndex()) {
            val isNew = !rows.containsKey(item.id)
            val row = rows.getOrPut(item.id) { messageRow() }
            if (row.label.text.toString() != item.label) row.label.text = item.label
            if (row.body.text.toString() != item.text) row.body.text = item.text
            row.label.setTextColor(if (item.kind == TaskPanelMessageKind.REASONING) color(if (dark) "#D6C8F0" else "#655184") else muted)
            row.body.typeface = if (item.kind == TaskPanelMessageKind.TOOL && item.text.startsWith("$ ")) Typeface.MONOSPACE else Typeface.DEFAULT
            if (list.indexOfChild(row.container) != index) {
                list.removeView(row.container); list.addView(row.container, index)
            }
            if (isNew && animate && motionDuration(170) > 0) {
                row.container.alpha = 0f; row.container.translationY = dp(6).toFloat()
                row.container.animate().alpha(1f).translationY(0f).setDuration(170).setInterpolator(easing).start()
            }
        }
    }

    private fun messageRow(): MessageRow {
        val container = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL; setPadding(0, dp(6), 0, dp(6))
        }
        val label = text(12f, muted)
        val body = text(14f, ink).apply { setPadding(0, dp(2), 0, 0) }
        container.addView(label); container.addView(body)
        return MessageRow(container, label, body)
    }

    private fun moveTo(target: TaskPanelFrame, animate: Boolean) {
        val root = view ?: return
        val layout = params ?: return
        motion?.cancel(); motion = null
        targetFrame = target
        val start = TaskPanelFrame(layout.x, layout.y, layout.width, layout.height)
        val bodyStart = scroll!!.alpha
        val activeStart = column!!.alpha
        val terminalStart = terminal!!.alpha
        val rotationStart = chevron!!.rotation
        val bodyEnd = if (expanded && !finished) 1f else 0f
        val activeEnd = if (finished) 0f else 1f
        val terminalEnd = if (finished) 1f else 0f
        val rotationEnd = if (expanded) 180f else 0f
        fun apply(progress: Float) {
            if (view !== root) return
            val frame = start.towards(target, progress)
            layout.x = frame.x; layout.y = frame.y; layout.width = frame.width; layout.height = frame.height
            fun mix(a: Float, b: Float) = a + (b - a) * progress
            scroll!!.alpha = mix(bodyStart, bodyEnd)
            footer!!.alpha = scroll!!.alpha
            column!!.alpha = mix(activeStart, activeEnd)
            terminal!!.alpha = mix(terminalStart, terminalEnd)
            chevron!!.rotation = mix(rotationStart, rotationEnd)
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

    private fun draggable(target: View) {
        val slop = ViewConfiguration.get(service).scaledTouchSlop
        target.setOnTouchListener { _, event ->
            val layout = params ?: return@setOnTouchListener false
            val root = view ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragX = event.rawX; dragY = event.rawY; originX = layout.x; originY = layout.y; dragging = false
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - dragX; val dy = event.rawY - dragY
                    if (abs(dx) > slop || abs(dy) > slop) dragging = true
                    if (dragging) {
                        motion?.cancel(); motion = null; targetFrame = null
                        val area = safeArea()
                        layout.x = (originX + dx.toInt()).coerceIn(area.left, (area.right - root.width).coerceAtLeast(area.left))
                        layout.y = (originY + dy.toInt()).coerceIn(area.top, (area.bottom - root.height).coerceAtLeast(area.top))
                        manager.updateViewLayout(root, layout); target.isPressed = false
                    }
                    dragging
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (!dragging) false else {
                        val area = safeArea()
                        position.dock(layout.x - area.left, layout.y - area.top, area.width(), area.height(), root.width, root.height)
                        dragging = false; target.isPressed = false
                        render(animate = true)
                        true
                    }
                }
                else -> false
            }
        }
    }

    private fun motionDuration(value: Long): Long {
        val enabled = if (Build.VERSION.SDK_INT >= 26) ValueAnimator.areAnimatorsEnabled()
        else Settings.Global.getFloat(service.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f
        return if (enabled) value else 0L
    }

    private fun textMotion(duration: Long) = AnimationSet(false).apply {
        addAnimation(AlphaAnimation(0f, 1f))
        addAnimation(TranslateAnimation(0f, 0f, dp(4).toFloat(), 0f))
        this.duration = duration; interpolator = easing
    }

    private fun safeArea(): Rect {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = manager.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            return Rect(metrics.bounds).apply {
                left += insets.left + dp(8); top += insets.top + dp(8)
                right -= insets.right + dp(8); bottom -= insets.bottom + dp(8)
            }
        }
        val metrics = service.resources.displayMetrics
        return Rect(dp(8), dp(32), metrics.widthPixels - dp(8), metrics.heightPixels - dp(56))
    }

    private fun text(size: Float, ink: Int) = TextView(service).apply { textSize = size; setTextColor(ink) }
    private fun icon(resource: Int, label: String, ink: Int, action: () -> Unit) = ImageButton(service).apply {
        setImageResource(resource); imageTintList = ColorStateList.valueOf(ink)
        setPadding(dp(12), dp(12), dp(12), dp(12)); background = ripple(Color.TRANSPARENT)
        contentDescription = label
        if (Build.VERSION.SDK_INT >= 26) tooltipText = label
        layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
        setOnClickListener { action() }
    }
    private fun exact(value: Int) = View.MeasureSpec.makeMeasureSpec(value, View.MeasureSpec.EXACTLY)
    private fun ripple(fill: Int) = RippleDrawable(ColorStateList.valueOf(color(if (dark) "#334F6BA5" else "#223D5A98")), shape(fill, 20), shape(Color.WHITE, 20))
    private fun shape(fill: Int, radius: Int) = GradientDrawable().apply { setColor(fill); cornerRadius = dp(radius).toFloat() }
    private fun dp(value: Int) = (value * service.resources.displayMetrics.density).toInt()
    private fun color(value: String) = Color.parseColor(value)
    private data class MessageRow(val container: LinearLayout, val label: TextView, val body: TextView)
}
