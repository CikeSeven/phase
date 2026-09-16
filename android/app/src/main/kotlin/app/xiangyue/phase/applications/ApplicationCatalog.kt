package app.xiangyue.phase.applications

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import app.xiangyue.phase.bridge.InstalledApplication
import java.io.File
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.ensureActive

class ApplicationCatalog(private val context: Context) {
    private val packages get() = context.packageManager

    suspend fun list(): List<InstalledApplication> = withContext(Dispatchers.IO) {
        if (ApplicationListPermission(context).isRequired()) throw ApplicationListPermissionRequired()
        val installed = try { packages.getInstalledPackages(0) }
            catch (_: SecurityException) { throw ApplicationListPermissionRequired() }
        requireApplicationInventory(installed.map { it.packageName }, context.packageName)
        val result = installed.mapNotNull { ensureActive(); describe(it) }
        if (result.isEmpty()) throw ApplicationCatalogUnavailable()
        result
    }

    suspend fun get(packageName: String): InstalledApplication? = withContext(Dispatchers.IO) {
        try { describe(packages.getPackageInfo(packageName, 0)) }
        catch (_: PackageManager.NameNotFoundException) { null }
    }

    suspend fun launchIntent(packageName: String): Intent? = withContext(Dispatchers.IO) {
        packages.getLaunchIntentForPackage(packageName)
    }

    private fun describe(info: PackageInfo): InstalledApplication? {
        val application = info.applicationInfo ?: return null
        return InstalledApplication(
            application.packageName,
            application.loadLabel(packages).toString().take(200),
            application.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0,
            info.firstInstallTime,
            packages.getLaunchIntentForPackage(application.packageName) != null,
            info.versionName?.take(100),
            apkSize(application),
        )
    }

    private fun apkSize(info: ApplicationInfo): Long? = try {
        val paths = (listOfNotNull(info.sourceDir) + (info.splitSourceDirs?.toList() ?: emptyList())).toSet()
        if (paths.isEmpty()) null else {
            val sizes = paths.map { File(it).let { file -> if (file.isFile) file.length().takeIf { size -> size > 0 } else null } }
            if (sizes.any { it == null }) null else sizes.filterNotNull().sum()
        }
    } catch (_: SecurityException) { null }

    companion object {
        fun sorted(apps: List<InstalledApplication>, sort: String): List<InstalledApplication> {
            val names = compareBy<InstalledApplication> { it.label.lowercase(Locale.ROOT) }.thenBy { it.packageName }
            val order = when (sort) {
                "name" -> names
                "installedAt" -> compareByDescending<InstalledApplication> { it.installedAtMs }.then(names)
                "size" -> compareBy<InstalledApplication> { it.sizeBytes == null }.thenByDescending { it.sizeBytes }.then(names)
                else -> throw IllegalArgumentException("sort")
            }
            return apps.sortedWith(order)
        }

        fun details(app: InstalledApplication): Map<String, Any?> = mapOf(
            "packageName" to app.packageName, "name" to app.label, "isSystem" to app.isSystem,
            "installedAtMs" to app.installedAtMs, "versionName" to app.versionName,
            "sizeBytes" to app.sizeBytes, "sizeKind" to "apk", "launchable" to app.launchable,
        )
    }
}
