package app.xiangyue.phase.execution

import android.content.Context
import app.xiangyue.phase.bridge.ExecutionHostApi
import app.xiangyue.phase.bridge.ExecutionFlutterApi
import app.xiangyue.phase.bridge.ExecutionSetupApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class ExecutionRuntime(context: Context) {
    val engine = FlutterEngine(context.applicationContext)
    val coordinator = ExecutionCoordinator(
        context.applicationContext,
        ExecutionFlutterApi(engine.dartExecutor.binaryMessenger),
    )

    init {
        ExecutionHostApi.setUp(engine.dartExecutor.binaryMessenger, coordinator)
        ExecutionSetupApi.setUp(engine.dartExecutor.binaryMessenger, coordinator.setup)
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
    }

    companion object {
        const val ENGINE_ID = "phase.execution"
    }
}
