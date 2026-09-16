package app.xiangyue.phase.applications

/** Validate the unfiltered platform response, never a searched or policy-filtered list. */
fun requireApplicationInventory(packageNames: List<String>, ownPackage: String) {
    if (packageNames.isEmpty()) throw ApplicationCatalogUnavailable()
    // A real phone inventory contains more than the calling app and the framework package.
    if (packageNames.none { it != ownPackage && it != "android" }) throw ApplicationCatalogRestricted()
}

class ApplicationListPermissionRequired : Exception()
class ApplicationCatalogRestricted : Exception()
class ApplicationCatalogUnavailable : Exception()
