package com.infralingo.data

import android.content.res.AssetManager
import com.infralingo.domain.Bank

class ContentRepository(private val assets: AssetManager) {
    fun load(): Bank {
        val manifest = assets.open("content/manifest.json").bufferedReader().use { it.readText() }
        val categories = assets.open("content/categories.json").bufferedReader().use { it.readText() }
        val skills = assets.open("content/skills.json").bufferedReader().use { it.readText() }
        val questionJsons = BankJson.parseManifest(manifest).map { name ->
            assets.open("content/questions/$name").bufferedReader().use { it.readText() }
        }
        return BankJson.parse(categories, skills, questionJsons)
    }
}
