package app.xiangyue.phase.accessibility

import android.content.Context
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextUtils
import android.widget.TextView

/** Fit the newest original lines at the actual width/font size; never summarize the model's text. */
class TaskPanelTextView(context: Context) : TextView(context) {
    private var response: String? = null

    init { maxLines = 2 }

    fun showHeadline(value: TaskPanelHeadline) {
        response = if (value.responseId != null) value.text else null
        ellipsize = if (response == null) TextUtils.TruncateAt.END else null
        text = value.text
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val source = response
        val available = MeasureSpec.getSize(widthMeasureSpec) - compoundPaddingLeft - compoundPaddingRight
        if (source != null && available > 0 && MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED) {
            val full = StaticLayout.Builder.obtain(source, 0, source.length, paint, available)
                .setIncludePad(includeFontPadding)
                .setTextDirection(if (layoutDirection == LAYOUT_DIRECTION_RTL) TextDirectionHeuristics.FIRSTSTRONG_RTL else TextDirectionHeuristics.FIRSTSTRONG_LTR)
                .setBreakStrategy(breakStrategy)
                .setHyphenationFrequency(hyphenationFrequency)
                .build()
            val start = if (full.lineCount > 2) full.getLineStart(full.lineCount - 2) else 0
            val visible = source.substring(start)
            if (text.toString() != visible) text = visible
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
}
