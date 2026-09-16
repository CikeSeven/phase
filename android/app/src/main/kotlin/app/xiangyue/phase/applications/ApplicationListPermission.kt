package app.xiangyue.phase.applications

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.PermissionInfo
import android.net.Uri
import android.provider.Settings

/** QUERY_ALL_PACKAGES is normal; some Android distributions add a dangerous runtime permission. */
class ApplicationListPermission(private val context: Context) {
    fun isRequired(): Boolean {
        val info = try { context.packageManager.getPermissionInfo(PERMISSION, 0) }
        catch (_: PackageManager.NameNotFoundException) { return false }
        return info.protectionLevel and PermissionInfo.PROTECTION_MASK_BASE == PermissionInfo.PROTECTION_DANGEROUS &&
            context.checkSelfPermission(PERMISSION) != PackageManager.PERMISSION_GRANTED
    }

    fun requestOnLaunch(activity: Activity) {
        if (isRequired()) activity.requestPermissions(arrayOf(PERMISSION), REQUEST_CODE)
    }

    fun openSettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
    }

    companion object {
        const val PERMISSION = "com.android.permission.GET_INSTALLED_APPS"
        const val REQUEST_CODE = 7411
    }
}
