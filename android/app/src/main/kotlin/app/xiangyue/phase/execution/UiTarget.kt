package app.xiangyue.phase.execution

import app.xiangyue.phase.bridge.ExecutionAction
import app.xiangyue.phase.bridge.ExecutionRequest
import app.xiangyue.phase.bridge.ExecutionTarget

/** Screenshot discovery uses the live foreground, never a model-supplied package or a cached target. */
fun resolveUiTarget(request: ExecutionRequest, foregroundPackage: () -> String?): String? {
    if (request.action == ExecutionAction.CAPTURE_SCREEN) {
        require(request.arguments.isEmpty() && request.target == ExecutionTarget())
        return foregroundPackage()?.takeIf { it.isNotBlank() }
    }
    val target = request.target.packageName
    require(!target.isNullOrBlank() && request.arguments["packageName"] == target)
    return target
}
