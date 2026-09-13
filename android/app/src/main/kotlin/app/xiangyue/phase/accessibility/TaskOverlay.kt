package app.xiangyue.phase.accessibility

import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.*
import app.xiangyue.phase.bridge.*
import org.json.JSONObject

/** Task-scoped accessibility overlay, never a global floating launcher. No business decisions here. */
class TaskOverlay(private val service: PhaseAccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var key: String? = null
    private var tick: Runnable? = null

    fun hide() {
        tick?.let(handler::removeCallbacks); tick = null
        view?.let { try { manager.removeView(it) } catch (_: IllegalArgumentException) {} }
        view = null; key = null
    }

    fun show(runId: String, confirmation: ExecutionConfirmation?, decide: (ConfirmationDecision) -> Unit, stop: () -> Unit) {
        val nextKey = "$runId:${confirmation?.toolCallId}:${service.resources.configuration.orientation}:${service.resources.configuration.uiMode}"
        if (view != null && key == nextKey) return
        hide(); key = nextKey
        val dark = service.resources.configuration.uiMode and 0x30 == 0x20
        val foreground = Color.parseColor(if (dark) "#F2EDF7" else "#211C29")
        val background = Color.parseColor(if (dark) "#27222F" else "#F5F0FA")
        val content = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(12))
            this.background = GradientDrawable().apply { setColor(background); cornerRadius = dp(24).toFloat() }
            elevation = dp(4).toFloat()
        }
        fun text(value: String, size: Float = 14f) = TextView(service).apply { text = value; textSize = size; setTextColor(foreground); setPadding(0, dp(4), 0, dp(4)) }
        fun button(label: String, action: () -> Unit) = Button(service).apply {
            text = label; textSize = 16f; minHeight = dp(48); isAllCaps = false
            val dangerous = label == "停止任务"
            val primary = label == "允许一次"
            val fill = if (dangerous) (if (dark) "#FFB4AB" else "#B3261E") else if (primary) (if (dark) "#D0BCFF" else "#6750A4") else (if (dark) "#3B3446" else "#E9E0EF")
            val ink = if (dangerous) (if (dark) "#690005" else "#FFFFFF") else if (primary) (if (dark) "#381E72" else "#FFFFFF") else (if (dark) "#F2EDF7" else "#211C29")
            setTextColor(Color.parseColor(ink))
            this.background = GradientDrawable().apply { setColor(Color.parseColor(fill)); cornerRadius = dp(16).toFloat() }
            layoutParams = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8) }
            setOnClickListener { isEnabled = false; action() }
        }
        content.addView(text(if (confirmation == null) "相月 · 任务执行中" else "相月 · ${confirmation.toolName}", 18f).apply { setTypeface(typeface, Typeface.BOLD) })
        if (confirmation != null) {
            val countdown = text("")
            content.addView(countdown)
            val scroll = ScrollView(service)
            val details = text("${confirmation.summary}\n目标：${confirmation.targetLabel ?: "选定 App"}\n执行通道：Android\n${JSONObject(confirmation.arguments).toString(2)}")
            details.setTextIsSelectable(true)
            scroll.addView(details)
            content.addView(scroll, LinearLayout.LayoutParams(-1, minOf(dp(220), service.resources.displayMetrics.heightPixels / 4)))
            content.addView(button("停止任务", stop))
            content.addView(button("拒绝") { hide(); decide(ConfirmationDecision.REJECT) })
            content.addView(button("允许一次") { hide(); decide(ConfirmationDecision.APPROVE) })
            tick = object : Runnable {
                override fun run() {
                    val seconds = ((confirmation.expiresAtMs - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
                    countdown.text = "剩余 $seconds 秒 · 仅本次动作"
                    if (seconds > 0) handler.postDelayed(this, 1000)
                }
            }.also(handler::post)
        } else {
            content.addView(button("停止任务", stop))
        }
        val metrics = service.resources.displayMetrics
        val params = WindowManager.LayoutParams(
            minOf(metrics.widthPixels - dp(24), dp(480)),
            if (confirmation == null) WindowManager.LayoutParams.WRAP_CONTENT else (metrics.heightPixels * 0.75).toInt(),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL; y = dp(24) }
        val rootView = if (confirmation == null) content else ScrollView(service).apply { isFillViewport = true; addView(content) }
        view = rootView
        manager.addView(rootView, params)
    }

    private fun dp(value: Int) = (value * service.resources.displayMetrics.density).toInt()
}
