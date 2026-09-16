package app.xiangyue.phase.applications

import app.xiangyue.phase.bridge.ApplicationListMode
import app.xiangyue.phase.bridge.ApplicationPolicy
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

    @Test fun normalInventoryMayStillBecomeAnEmptyWhitelistAfterValidation() {
        val packages = listOf(own, "android", "com.android.settings", "fixture.notes")
        requireApplicationInventory(packages, own)
        val emptyWhitelist = ApplicationPolicy(ApplicationListMode.WHITELIST, emptyList(), emptyList(), emptyList())
        assertTrue(packages.none { ApplicationAccess.allows(emptyWhitelist, emptyWhitelist, it, false) })
        // Keeping 相月 selectable is independent from rejecting a system-truncated inventory.
        val ownWhitelist = ApplicationPolicy(ApplicationListMode.WHITELIST, emptyList(), listOf(own), emptyList())
        assertTrue(ApplicationAccess.allows(ownWhitelist, ownWhitelist, own, false))
    }
}
