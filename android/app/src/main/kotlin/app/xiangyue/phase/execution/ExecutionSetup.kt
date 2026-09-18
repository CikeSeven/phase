package app.xiangyue.phase.execution

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import app.xiangyue.phase.MainActivity
import app.xiangyue.phase.bridge.*
import app.xiangyue.phase.files.SkillDirectoryImporter
import app.xiangyue.phase.files.AppFileDriver
import app.xiangyue.phase.applications.ApplicationCatalog
import app.xiangyue.phase.applications.ApplicationCatalogUnavailable
import app.xiangyue.phase.applications.ApplicationCatalogRestricted
import app.xiangyue.phase.applications.ApplicationListPermission
import app.xiangyue.phase.applications.ApplicationListPermissionRequired
import kotlinx.coroutines.*
import java.lang.ref.WeakReference

/** User-driven setup only. Picker cancellation does not change the saved selection. */
class ExecutionSetup(private val context: Context, private val files: AppFileDriver,
    private val applications: ApplicationCatalog, private val applyPolicy: (ApplicationPolicy) -> Unit) : ExecutionSetupApi {
    private var activity = WeakReference<MainActivity>(null)
    private var pending: CompletableDeferred<Uri?>? = null
    private var pendingCode = PICK_FILE
    private var persistSelection = true
    private var importId: String? = null
    private val skillImporter = SkillDirectoryImporter(context)

    fun attach(value: MainActivity) { activity = WeakReference(value) }
    fun detach(value: MainActivity) { if (activity.get() === value) activity.clear() }

    override suspend fun selectFile(directory: Boolean): FileGrant? {
        val uri = pick(directory, persist = true) ?: return null
        return files.grants().firstOrNull { it.uri == uri.toString() }
            ?: throw FlutterError("permissionRequired", "文件授权未保留", null)
    }

    private suspend fun pick(directory: Boolean, persist: Boolean): Uri? {
        if (pending != null) throw FlutterError("unavailable", "已有文件选择器", null)
        val host = activity.get() ?: throw FlutterError("unavailable", "请返回相月", null)
        val result = CompletableDeferred<Uri?>()
        pending = result
        persistSelection = persist
        pendingCode = if (pendingCode == 65534) PICK_FILE else pendingCode + 1
        try {
            host.startActivityForResult(Intent(if (directory) Intent.ACTION_OPEN_DOCUMENT_TREE else Intent.ACTION_OPEN_DOCUMENT).apply {
                if (!directory) { type = "*/*"; addCategory(Intent.CATEGORY_OPENABLE) }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (persist) addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }, pendingCode)
            return withTimeout(120000) { result.await() }
        } catch (error: FlutterError) { throw error }
        catch (_: Exception) { throw FlutterError("unavailable", "文件选择未完成", null) }
        finally { if (pending === result) pending = null }
    }

    fun pickerResult(requestCode: Int, code: Int, data: Intent?) {
        if (requestCode != pendingCode) return
        val request = pending ?: return
        if (request.isCompleted) return
        if (code != Activity.RESULT_OK || data?.data == null) { request.complete(null); return }
        try {
            if (persistSelection) {
                val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                context.contentResolver.takePersistableUriPermission(data.data!!, flags)
            }
            request.complete(data.data)
        } catch (_: Exception) { request.completeExceptionally(FlutterError("permissionRequired", "无法读取所选目录", null)) }
    }

    override suspend fun importSkillDirectory(request: SkillDirectoryImport): SkillDirectoryCopy? {
        if (importId != null || pending != null) throw FlutterError("unavailable", "已有文件导入任务", null)
        importId = request.id
        skillImporter.begin(request.id)
        try {
            val uri = pick(directory = true, persist = false) ?: return null
            return skillImporter.copy(uri, request)
        } finally {
            skillImporter.finish(request.id)
            importId = null
        }
    }

    override fun cancelSkillImport(id: String) {
        if (id != importId) return
        skillImporter.cancel(id)
        pending?.takeUnless { it.isCompleted }?.complete(null)
    }

    override suspend fun fileGrants(): List<FileGrant> = boundary { files.grants() }
    override fun releaseFileGrant(uri: String) {
        try { files.release(uri) } catch (_: Exception) { throw FlutterError("permissionRequired", "解除授权失败", null) }
    }

    override suspend fun installedApplications(): List<InstalledApplication> = try { applications.list() }
        catch (error: CancellationException) { throw error }
        catch (_: ApplicationListPermissionRequired) { throw FlutterError("applicationListPermissionRequired", "未授权获取应用列表", null) }
        catch (_: ApplicationCatalogRestricted) { throw FlutterError("applicationListRestricted", "应用列表访问受限", null) }
        catch (_: ApplicationCatalogUnavailable) { throw FlutterError("applicationListUnavailable", "系统未返回应用列表", null) }
        catch (_: Exception) { throw FlutterError("unavailable", "读取应用列表失败", null) }
    override fun updateApplicationPolicy(policy: ApplicationPolicy) = applyPolicy(policy)

    override fun openPermissionSettings(screen: PermissionScreen) {
        val host = activity.get() ?: throw FlutterError("unavailable", "请返回相月", null)
        if (screen == PermissionScreen.APPLICATIONS) {
            try { ApplicationListPermission(context).openSettings(host) }
            catch (_: Exception) { throw FlutterError("unavailable", "无法打开应用权限设置", null) }
            return
        }
        val intent = if (screen == PermissionScreen.ACCESSIBILITY) Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        else if (android.os.Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
        try { host.startActivity(intent) } catch (_: Exception) { throw FlutterError("unavailable", "无法打开系统设置", null) }
    }

    private suspend fun <T> boundary(action: suspend () -> T): T = try { action() }
        catch (_: SecurityException) { throw FlutterError("permissionRequired", "文件授权已失效", null) }
        catch (_: Exception) { throw FlutterError("unavailable", "文件访问失败", null) }

    companion object { const val PICK_FILE = 7410 }
}
