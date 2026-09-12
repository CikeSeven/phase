package app.xiangyue.phase

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val runtime get() = (application as PhaseApplication).runtime

    override fun provideFlutterEngine(context: Context): FlutterEngine = runtime.engine

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        runtime.coordinator.setActivityResumed(true)
    }

    override fun onPause() {
        runtime.coordinator.setActivityResumed(false)
        super.onPause()
    }
}
