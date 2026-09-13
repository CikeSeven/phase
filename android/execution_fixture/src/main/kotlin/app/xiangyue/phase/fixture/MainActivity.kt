package app.xiangyue.phase.fixture

import android.app.Activity
import android.os.Bundle
import android.widget.*

/** Fixed data, no network or personal state. Reopening always resets the search page. */
class MainActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (intent.getBooleanExtra("grant_fixture", false)) {
            val uri = android.provider.DocumentsContract.buildTreeDocumentUri("app.xiangyue.phase.fixture.documents", "root")
            setResult(RESULT_OK, android.content.Intent().setData(uri).addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION or android.content.Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or android.content.Intent.FLAG_GRANT_PREFIX_URI_PERMISSION))
            finish(); return
        }
        searchPage()
    }
    private fun searchPage() {
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(24, 48, 24, 24) }
        layout.addView(TextView(this).apply { text = "相月执行测试 · 搜索预置条目"; textSize = 20f })
        val input = EditText(this).apply { id = R.id.search_input; hint = "输入搜索内容"; setSingleLine(true) }
        layout.addView(input)
        val results = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val scroll = ScrollView(this).apply { id = R.id.search_results; addView(results) }
        layout.addView(Button(this).apply {
            id = R.id.search_button; text = "搜索"
            setOnClickListener {
                results.removeAllViews()
                val query = input.text.toString()
                (listOf("AI Agent", "Flutter", "Android") + (1..30).map { "预置条目 $it" })
                    .filter { it.contains(query, ignoreCase = true) }.forEach { title ->
                        results.addView(Button(this@MainActivity).apply { id = R.id.result_item; text = title; setOnClickListener { detail(title) } })
                    }
                if (results.childCount == 0) results.addView(TextView(this@MainActivity).apply { text = "没有匹配条目" })
                input.clearFocus()
                getSystemService(android.view.inputmethod.InputMethodManager::class.java).hideSoftInputFromWindow(input.windowToken, 0)
            }
        })
        layout.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(layout)
    }
    private fun detail(title: String) {
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(24, 48, 24, 24)
            addView(TextView(this@MainActivity).apply { id = R.id.detail_title; text = "$title · 详情"; textSize = 24f })
            addView(TextView(this@MainActivity).apply { text = "这是固定测试条目的详情内容，不调用网络。"; textSize = 18f })
            addView(Button(this@MainActivity).apply { text = "返回搜索"; setOnClickListener { searchPage() } })
        })
    }
}
