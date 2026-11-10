package com.infralingo.data

import com.infralingo.domain.Bank
import com.infralingo.domain.Category
import com.infralingo.domain.Difficulty
import com.infralingo.domain.Question
import com.infralingo.domain.Skill
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

object BankJson {
    private val json = Json { ignoreUnknownKeys = true }

    @Serializable
    data class CategoryDto(
        val id: String,
        val title: String,
        val blurb: String,
        val order: Int,
    )

    @Serializable
    data class SkillDto(
        val id: String,
        val categoryId: String,
        val title: String,
        val order: Int,
    )

    @Serializable
    data class QuestionDto(
        val id: String,
        val skillId: String,
        val difficulty: String,
        val prompt: String,
        val choices: List<String>,
        val answer: Int,
        val explanation: String,
        val source: String,
        val url: String = "",
    )

    @Serializable
    data class ManifestDto(val questionFiles: List<String>)

    fun parseManifest(raw: String): List<String> = json.decodeFromString<ManifestDto>(raw).questionFiles

    fun parse(categoriesJson: String, skillsJson: String, questionJsons: List<String>): Bank {
        val categories = json.decodeFromString<List<CategoryDto>>(categoriesJson).map {
            Category(id = it.id, title = it.title, blurb = it.blurb, order = it.order)
        }
        val skills = json.decodeFromString<List<SkillDto>>(skillsJson).map {
            Skill(id = it.id, categoryId = it.categoryId, title = it.title, order = it.order)
        }
        val questions = questionJsons.flatMap { raw ->
            json.decodeFromString<List<QuestionDto>>(raw).map { dto ->
                Question(
                    id = dto.id,
                    skillId = dto.skillId,
                    difficulty = Difficulty.parse(dto.difficulty),
                    prompt = dto.prompt.trim(),
                    choices = dto.choices.map { it.trim() },
                    answerIndex = dto.answer,
                    explanation = dto.explanation.trim(),
                    source = dto.source,
                    url = dto.url,
                )
            }
        }
        validate(categories, skills, questions)
        return Bank(
            categories = categories.sortedBy { it.order },
            skills = skills.sortedWith(compareBy({ it.categoryId }, { it.order })),
            questions = questions,
        )
    }

    fun validate(categories: List<Category>, skills: List<Skill>, questions: List<Question>) {
        val categoryIds = categories.map { it.id }
        require(categoryIds.distinct().size == categoryIds.size) { "Duplicate category id" }
        val skillIds = skills.map { it.id }
        require(skillIds.distinct().size == skillIds.size) { "Duplicate skill id" }
        val questionIds = questions.map { it.id }
        require(questionIds.distinct().size == questionIds.size) { "Duplicate question id" }
        val categorySet = categoryIds.toSet()
        skills.forEach { skill ->
            require(skill.categoryId in categorySet) { "Skill ${skill.id} has unknown category ${skill.categoryId}" }
        }
        val skillSet = skillIds.toSet()
        questions.forEach { question ->
            require(question.skillId in skillSet) { "Question ${question.id} has unknown skill ${question.skillId}" }
            require(question.choices.size == 4) { "Question ${question.id} needs 4 choices" }
            require(question.choices.distinct().size == 4) { "Question ${question.id} has duplicate choices" }
            require(question.answerIndex in question.choices.indices) { "Question ${question.id} has a bad answer index" }
            require(question.prompt.isNotBlank()) { "Question ${question.id} has an empty prompt" }
            require(question.explanation.isNotBlank()) { "Question ${question.id} has an empty explanation" }
        }
        val bySkill = questions.groupBy { it.skillId }
        skills.forEach { skill ->
            val count = bySkill[skill.id].orEmpty().size
            require(count >= 4) { "Skill ${skill.id} has $count questions, need at least 4" }
        }
        val skillCategory = skills.associate { it.id to it.categoryId }
        categories.forEach { category ->
            val medium = questions.any { question ->
                skillCategory[question.skillId] == category.id && question.difficulty == Difficulty.MEDIUM
            }
            require(medium) { "Category ${category.id} has no medium question for placement" }
        }
    }
}
