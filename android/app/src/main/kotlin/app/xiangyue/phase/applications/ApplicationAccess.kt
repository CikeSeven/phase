package app.xiangyue.phase.applications

import app.xiangyue.phase.bridge.ApplicationListMode
import app.xiangyue.phase.bridge.ApplicationPolicy

/** Shared by discovery and dispatch. Unknown/non-installed packages never reach this predicate. */
object ApplicationAccess {
    fun allows(policy: ApplicationPolicy, packageName: String, isSystem: Boolean): Boolean =
        when (policy.mode) {
            ApplicationListMode.WHITELIST -> packageName in policy.whitelist
            ApplicationListMode.BLACKLIST -> packageName !in policy.blacklist &&
                (!isSystem || packageName in policy.allowedSystemApps)
        }

    fun allows(snapshot: ApplicationPolicy, current: ApplicationPolicy, packageName: String, isSystem: Boolean): Boolean =
        allows(snapshot, packageName, isSystem) && allows(current, packageName, isSystem)
}
