package app.xiangyue.phase

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import app.xiangyue.phase.bridge.*
import app.xiangyue.phase.execution.ExecutionCoordinator
import kotlinx.coroutines.*
import org.json.JSONObject
import java.util.UUID

/** On-device native smoke test; no model, credentials, conversations or unrelated files are read. */
class ExecutionSmokeRunner : Instrumentation() {
    private var options = Bundle()
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); options = arguments ?: Bundle(); start() }
    override fun onStart() {
        val report = Bundle()
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        val deadline = Runnable { finish(Activity.RESULT_CANCELED, Bundle().apply { putString("phase_result", "timed out"); putString("phase_stage", stage) }) }
        handler.postDelayed(deadline, 30000)
        try {
            runBlocking { runScenario(report) }
            handler.removeCallbacks(deadline)
            finish(Activity.RESULT_OK, report)
        } catch (error: Throwable) {
            handler.removeCallbacks(deadline)
            report.putString("phase_result", "failed: ${error.javaClass.simpleName}")
            report.putString("phase_stage", stage)
            finish(Activity.RESULT_CANCELED, report)
        }
    }
    private var stage = "start"
    private var targetPackage = ""
    private fun policy() = ApplicationPolicy(ApplicationListMode.BLACKLIST, emptyList(), emptyList(), emptyList())
    private fun session(id: String, device: Boolean, roots: List<String> = emptyList()) = ExecutionSession(id, device, roots, policy(), policy())
    private suspend fun runScenario(report: Bundle) {
        val scenario = options.getString("scenario") ?: "fixture"
        val target = if (scenario.startsWith("bili")) "tv.danmaku.bili" else "app.xiangyue.phase.fixture"
        targetPackage = target
        val id = "smoke-${UUID.randomUUID()}"
        val app = targetContext.applicationContext as PhaseApplication
        if (scenario == "applications") {
            val coordinator = withContext(Dispatchers.Main) { app.runtime.coordinator }
            applicationScenario(coordinator, id, report)
            return
        }
        val activity = startActivitySync(Intent(targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        val coordinator = withContext(Dispatchers.Main) { app.runtime.coordinator }
        withTimeout(5000) { while (!withContext(Dispatchers.Main) { coordinator.queryCapabilities().activityResumed }) delay(20) }
        stage = "engine-recreation"
        val engine = withContext(Dispatchers.Main) { app.runtime.engine }
        val monitor = addMonitor(MainActivity::class.java.name, null, false)
        runOnMainSync { activity.recreate() }
        val recreated = waitForMonitorWithTimeout(monitor, 5000) ?: error("Activity did not recreate")
        removeMonitor(monitor)
        withTimeout(5000) { while (!withContext(Dispatchers.Main) { coordinator.queryCapabilities().activityResumed }) delay(20) }
        check(withContext(Dispatchers.Main) { app.runtime.engine === engine && engine.dartExecutor.isExecutingDart })
        if (scenario == "files") { fileScenario(coordinator, id, report, recreated); return }
        stage = "permissions"
        val caps = withContext(Dispatchers.Main) { coordinator.queryCapabilities() }
        check(caps.notificationsAllowed && caps.accessibilityConnected)
        try {
            stage = "host-and-target"
            check(withContext(Dispatchers.Main) { coordinator.startRun(session(id, true)).error } == null)
            var snapshot = snapshot(call(coordinator, id, ExecutionAction.OPEN_APP))
            if (scenario.startsWith("bili")) {
                val candidates = nodes(snapshot).filter { "${it["text"]} ${it["description"]}".contains("搜索") }
                if (scenario == "bili-inspect") {
                    report.putString("phase_controls", JSONObject(mapOf("controls" to candidates.map { mapOf("id" to it["id"], "text" to it["text"], "description" to it["description"], "clickable" to it["clickable"], "editable" to it["editable"]) })).toString())
                    report.putString("phase_result", "observed search controls only")
                    return
                }
                stage = "open-search"
                val search = candidates.firstOrNull { it["clickable"] == true } ?: candidates.first()
                snapshot = snapshot(call(coordinator, id, ExecutionAction.CLICK_NODE, snapshot, search))
            }
            stage = "input"
            val field = nodes(snapshot).first { it["editable"] == true }
            snapshot = snapshot(call(coordinator, id, ExecutionAction.INPUT_TEXT, snapshot, field, mapOf("text" to "AI Agent")))
            stage = "search"
            val search = nodes(snapshot).first { it["text"] == "搜索" && it["clickable"] == true }
            snapshot = snapshot(call(coordinator, id, ExecutionAction.CLICK_NODE, snapshot, search))
            if (scenario == "fixture") {
                stage = "detail"
                val item = nodes(snapshot).first { it["text"] == "AI Agent" && it["clickable"] == true }
                snapshot = snapshot(call(coordinator, id, ExecutionAction.CLICK_NODE, snapshot, item))
                check(nodes(snapshot).any { it["text"] == "AI Agent · 详情" })
            } else {
                // Re-observe the search page; never open an arbitrary recommended video/account.
                snapshot = snapshot(call(coordinator, id, ExecutionAction.INSPECT_UI))
                check(nodes(snapshot).any { "${it["text"]} ${it["description"]}".contains("AI Agent", ignoreCase = true) })
            }
            stage = "native-stop"
            val notifications = targetContext.getSystemService(android.app.NotificationManager::class.java)
            val notification = notifications.activeNotifications.first { it.id == 4102 }.notification
            notification.actions.first { it.title.toString() == "停止任务" }.actionIntent.send()
            withTimeout(3000) { while (notifications.activeNotifications.any { it.id == 4102 }) delay(20) }
            check(withContext(Dispatchers.Main) { coordinator.execute(ExecutionRequest(id, UUID.randomUUID().toString(), ExecutionAction.INSPECT_UI, emptyMap(), ExecutionTarget(), 5000)).status } == ExecutionStatus.CANCELLED)
            report.putString("phase_result", "passed: $scenario search, observations, cached engine, notification stop")
        } finally { withContext(Dispatchers.Main) { coordinator.endRun(id) } }
    }

    private suspend fun call(coordinator: ExecutionCoordinator, run: String, action: ExecutionAction, snapshot: Map<String, Any?>? = null, node: Map<String, Any?>? = null, arguments: Map<String, Any?> = emptyMap()): ExecutionResult {
        val request = ExecutionRequest(run, UUID.randomUUID().toString(), action, arguments + ("packageName" to targetPackage),
            ExecutionTarget(packageName = targetPackage, snapshotId = snapshot?.get("id") as? String, nodeId = node?.get("id") as? String), 10000)
        val result = withContext(Dispatchers.Main) { coordinator.execute(request) }
        check(result.status == ExecutionStatus.SUCCEEDED) { "Action did not complete" }
        return result
    }

    private suspend fun fileScenario(coordinator: ExecutionCoordinator, id: String, report: Bundle, activity: Activity) {
        stage = "fixture-file-grant"
        val uri = android.provider.DocumentsContract.buildTreeDocumentUri("app.xiangyue.phase.fixture.documents", "root")
        runOnMainSync { activity.startActivityForResult(Intent().setClassName("app.xiangyue.phase.fixture", "app.xiangyue.phase.fixture.MainActivity").putExtra("grant_fixture", true), 7410) }
        withTimeout(5000) {
            while (true) {
                try { targetContext.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION); break }
                catch (_: SecurityException) { delay(30) }
            }
        }
        val root = uri.toString()
        try {
            check(withContext(Dispatchers.Main) { coordinator.startRun(session(id, false, listOf(root))).error } == null)
            suspend fun execute(action: ExecutionAction, args: Map<String, Any?>) = withContext(Dispatchers.Main) {
                coordinator.execute(ExecutionRequest(id, UUID.randomUUID().toString(), action, args, ExecutionTarget(uri = root), 10000))
            }
            stage = "saf-list"
            check(execute(ExecutionAction.LIST_FILES, emptyMap()).status == ExecutionStatus.SUCCEEDED)
            val name = "smoke-${UUID.randomUUID()}.txt"
            stage = "saf-write-readback"
            val written = execute(ExecutionAction.WRITE_FILE, mapOf("path" to name, "content" to "AI Agent 测试摘要"))
            check(written.status == ExecutionStatus.SUCCEEDED)
            check(java.io.File(written.artifacts.single().localPath!!).readText() == "AI Agent 测试摘要")
            stage = "saf-overwrite-guard"
            check(execute(ExecutionAction.WRITE_FILE, mapOf("path" to name, "content" to "wrong")).error == ChannelError.TARGET_CHANGED)
            check(execute(ExecutionAction.WRITE_FILE, mapOf("path" to name, "content" to "wrong", "overwrite" to true, "expectedSha256" to "wrong")).error == ChannelError.TARGET_CHANGED)
            check(execute(ExecutionAction.WRITE_FILE, mapOf("path" to "../escape.txt", "content" to "wrong")).error == ChannelError.INVALID_ARGUMENTS)
            val overwritten = execute(ExecutionAction.WRITE_FILE, mapOf("path" to name, "content" to "更新后的测试摘要", "overwrite" to true, "expectedSha256" to written.artifacts.single().sha256))
            check(overwritten.status == ExecutionStatus.SUCCEEDED)
            check(java.io.File(overwritten.artifacts.single().localPath!!).readText() == "更新后的测试摘要")
            stage = "saf-scope"
            val denied = coordinator.files.execute(ExecutionRequest(id, "denied", ExecutionAction.LIST_FILES, emptyMap(), ExecutionTarget(uri = root), 10000), emptyList())
            check(denied.error == ChannelError.PERMISSION_REQUIRED)
            report.putString("phase_result", "passed: real SAF list, create, readback, overwrite hash, path and scope guards")
        } finally { withContext(Dispatchers.Main) { coordinator.endRun(id) } }
    }

    private suspend fun applicationScenario(coordinator: ExecutionCoordinator, id: String, report: Bundle) {
        val fixture = "app.xiangyue.phase.fixture"
        suspend fun call(action: ExecutionAction, arguments: Map<String, Any?>, target: String? = null) = withContext(Dispatchers.Main) {
            coordinator.execute(ExecutionRequest(id, UUID.randomUUID().toString(), action, arguments, ExecutionTarget(packageName = target), 15000))
        }
        try {
            stage = "application-default-list"
            check(withContext(Dispatchers.Main) { coordinator.startRun(session(id, false)).error } == null)
            val initial = call(ExecutionAction.LIST_APPS, mapOf("query" to fixture))
            report.putString("phase_native_status", "${initial.status}/${initial.error}")
            report.putInt("phase_fixture_count", (initial.result["applications"] as? List<*>)?.size ?: -1)
            check(initial.status == ExecutionStatus.SUCCEEDED && (initial.result["applications"] as List<*>).size == 1)
            val blocked = ApplicationPolicy(ApplicationListMode.BLACKLIST, listOf(fixture), emptyList(), emptyList())
            withContext(Dispatchers.Main) { coordinator.setup.updateApplicationPolicy(blocked) }
            stage = "application-blacklist-list"
            check((call(ExecutionAction.LIST_APPS, mapOf("query" to fixture)).result["applications"] as List<*>).isEmpty())
            stage = "application-dispatch-denial"
            val denied = call(ExecutionAction.OPEN_APP, mapOf("packageName" to fixture), fixture)
            check(denied.status == ExecutionStatus.FAILED && denied.result["reasonCode"] == "applicationDenied")
            check(call(ExecutionAction.OPEN_APP, mapOf("packageName" to fixture), "android").error == ChannelError.INVALID_ARGUMENTS)
            withContext(Dispatchers.Main) { coordinator.endRun(id) }
            stage = "application-whitelist-list"
            val white = ApplicationPolicy(ApplicationListMode.WHITELIST, emptyList(), listOf(fixture), emptyList())
            check(withContext(Dispatchers.Main) { coordinator.startRun(ExecutionSession(id, false, emptyList(), white, white)).error } == null)
            val allowed = call(ExecutionAction.LIST_APPS, emptyMap())
            check((allowed.result["applications"] as List<*>).size == 1)
            check((allowed.result["applications"] as List<*>).first().let { (it as Map<*, *>)["packageName"] } == fixture)
            report.putString("phase_result", "passed: native list filtering, blacklist dispatch guard, package mismatch, whitelist")
        } finally { withContext(Dispatchers.Main) { coordinator.endRun(id) } }
    }
    @Suppress("UNCHECKED_CAST")
    private fun snapshot(result: ExecutionResult) = result.result["snapshot"] as Map<String, Any?>
    @Suppress("UNCHECKED_CAST")
    private fun nodes(snapshot: Map<String, Any?>) = snapshot["nodes"] as List<Map<String, Any?>>
}
