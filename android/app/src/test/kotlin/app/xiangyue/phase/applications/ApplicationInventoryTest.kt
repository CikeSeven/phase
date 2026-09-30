package app.xiangyue.phase.applications

import org.junit.Assert.*
import org.junit.Test

class ApplicationInventoryTest {
    private val own = "app.xiangyue.phase"

    @Test fun selfOnlyResponseIsRestrictedRatherThanAValidOneAppInventory() {
        assertThrows(ApplicationCatalogRestricted::class.java) {
            requireApplicationInventory(listOf(own), own)
        }
        assertThrows(ApplicationCatalogRestricted::class.java) {
            requireApplicationInventory(listOf(own, "android"), own)
        }
    }

    @Test fun emptyPlatformResponseRemainsUnavailableRatherThanPermissionDenied() {
        assertThrows(ApplicationCatalogUnavailable::class.java) {
            requireApplicationInventory(emptyList(), own)
        }
    }

    @Test fun inventoryContainingSystemAndThirdPartyAppsIsAccepted() {
        val packages = listOf(own, "android", "com.android.settings", "fixture.notes")
        requireApplicationInventory(packages, own)
    }
}
