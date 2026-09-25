package app.xiangyue.phase

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import app.xiangyue.phase.applications.ApplicationListPermission
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val runtime get() = (application as PhaseApplication).runtime
    private var checkedApplicationListPermission = false

    override fun onCreate(savedInstanceState: Bundle?) {
        checkedApplicationListPermission = savedInstanceState?.getBoolean("applicationListPermissionChecked") ?: false
        super.onCreate(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("applicationListPermissionChecked", checkedApplicationListPermission)
        super.onSaveInstanceState(outState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = runtime.engine

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        runtime.coordinator.setup.attach(this)
        runtime.commands.attach(this)
        runtime.coordinator.setActivityResumed(true)
        if (!checkedApplicationListPermission) {
            // Set before dispatch: dismissing the permission dialog resumes this Activity again.
            checkedApplicationListPermission = true
            ApplicationListPermission(this).requestOnLaunch(this)
        }
    }

    override fun onPause() {
        runtime.coordinator.setActivityResumed(false)
        super.onPause()
    }

    override fun onDestroy() {
        runtime.coordinator.setup.detach(this)
        runtime.commands.detach(this)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4602) runtime.commands.changed()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        runtime.coordinator.setup.pickerResult(requestCode, resultCode, data)
    }
}
