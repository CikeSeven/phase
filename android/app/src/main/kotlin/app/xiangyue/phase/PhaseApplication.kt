package app.xiangyue.phase

import android.app.Application
import app.xiangyue.phase.execution.ExecutionRuntime

class PhaseApplication : Application() {
    // 单进程单引擎；服务/Activity 只获得同一个运行宿主，不重新调用 Dart main。
    val runtime: ExecutionRuntime by lazy { ExecutionRuntime(this) }
}
