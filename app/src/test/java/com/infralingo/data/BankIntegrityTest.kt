package com.infralingo.data

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class BankIntegrityTest {
    @Test
    fun bundledBankMeetsTheSkillFloor() {
        val root = File("src/main/assets/content")
        val manifest = File(root, "manifest.json").readText()
        val categories = File(root, "categories.json").readText()
        val skills = File(root, "skills.json").readText()
        val files = BankJson.parseManifest(manifest).map { name ->
            File(root, "questions/$name").readText()
        }
        val bank = BankJson.parse(categories, skills, files)
        assertTrue(bank.questions.size >= 400)
        assertTrue(bank.categories.size >= 10)
    }
}
