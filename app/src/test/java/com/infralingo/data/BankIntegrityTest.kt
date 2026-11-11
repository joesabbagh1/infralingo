package com.infralingo.data

import com.infralingo.domain.Bank
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class BankIntegrityTest {
    private fun bundledBank(): Bank {
        val root = File("src/main/assets/content")
        val manifest = File(root, "manifest.json").readText()
        val categories = File(root, "categories.json").readText()
        val skills = File(root, "skills.json").readText()
        val files = BankJson.parseManifest(manifest).map { name ->
            File(root, "questions/$name").readText()
        }
        return BankJson.parse(categories, skills, files)
    }

    @Test
    fun bundledBankMeetsTheSkillFloor() {
        val bank = bundledBank()
        assertTrue(bank.questions.size >= 400)
        assertTrue(bank.categories.size >= 10)
    }

    @Test
    fun theLongestChoiceIsNotATell() {
        // Picking the longest choice blind should score near chance (25%), not near the answer key.
        val questions = bundledBank().questions
        val longestWins = questions.count { q ->
            val correct = q.choices[q.answerIndex].length
            q.choices.withIndex().all { (i, c) -> i == q.answerIndex || c.length < correct }
        }
        val share = longestWins.toDouble() / questions.size
        assertTrue("correct choice is strictly longest in ${"%.0f".format(share * 100)}% of questions", share < 0.45)
    }
}
