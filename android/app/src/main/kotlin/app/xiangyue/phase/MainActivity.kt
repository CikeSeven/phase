package app.xiangyue.phase

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import android.content.Intent
import app.xiangyue.phase.execution.ExecutionSetup
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val runtime get() = (application as PhaseApplication).runtime

    override fun provideFlutterEngine(context: Context): FlutterEngine = runtime.engine

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        runtime.coordinator.setup.attach(this)
        runtime.coordinator.setActivityResumed(true)
    }

    override fun onPause() {
        runtime.coordinator.setActivityResumed(false)
        super.onPause()
    }

    override fun onDestroy() {
        runtime.coordinator.setup.detach(this)
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ExecutionSetup.PICK_FILE) runtime.coordinator.setup.pickerResult(resultCode, data)
    }
}
