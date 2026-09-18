package app.xiangyue.phase.execution

import app.xiangyue.phase.files.SkillImportBudget
import org.junit.Assert.assertThrows
import org.junit.Test

class SkillImportBudgetTest {
    private fun budget() = SkillImportBudget(3, 8, 5, 3, 40)
    @Test fun rejectsPathsAndDuplicateProviderNames() {
        for (path in listOf("../outside", "/absolute", "a//b", "a/./b", "a\\b", "a:b", "a/b/c/d")) {
            assertThrows(IllegalArgumentException::class.java) { budget().entry(path) }
        }
        val budget = budget()
        budget.entry("a/b")
        assertThrows(IllegalArgumentException::class.java) { budget.entry("a/b") }
    }
    @Test fun checksActualBytesPerFileAndTotal() {
        val budget = budget()
        budget.entry("a")
        budget.chunk(5)
        budget.entry("b")
        budget.chunk(3)
        assertThrows(IllegalArgumentException::class.java) { budget.chunk(1) }
        val another = budget()
        another.entry("a")
        assertThrows(IllegalArgumentException::class.java) { another.chunk(6) }
    }
    @Test fun directoriesAlsoCountTowardsLimit() {
        val budget = budget()
        budget.entry("a"); budget.entry("a/b"); budget.entry("a/b/c")
        assertThrows(IllegalArgumentException::class.java) { budget.entry("d") }
    }
}
