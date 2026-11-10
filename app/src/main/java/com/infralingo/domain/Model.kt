package com.infralingo.domain

enum class Difficulty {
    EASY,
    MEDIUM,
    HARD,
    ;

    companion object {
        fun parse(raw: String): Difficulty = when (raw.lowercase()) {
            "easy" -> EASY
            "medium" -> MEDIUM
            "hard" -> HARD
            else -> throw IllegalArgumentException("Unknown difficulty: $raw")
        }
    }
}

data class Category(
    val id: String,
    val title: String,
    val blurb: String,
    val order: Int,
)

data class Skill(
    val id: String,
    val categoryId: String,
    val title: String,
    val order: Int,
)

data class Question(
    val id: String,
    val skillId: String,
    val difficulty: Difficulty,
    val prompt: String,
    val choices: List<String>,
    val answerIndex: Int,
    val explanation: String,
    val source: String,
    val url: String,
)

data class Bank(
    val categories: List<Category>,
    val skills: List<Skill>,
    val questions: List<Question>,
) {
    val categoriesById: Map<String, Category> = categories.associateBy { it.id }
    val skillsById: Map<String, Skill> = skills.associateBy { it.id }
    val questionsById: Map<String, Question> = questions.associateBy { it.id }
    val questionsBySkill: Map<String, List<Question>> = questions.groupBy { it.skillId }
    val skillsByCategory: Map<String, List<Skill>> =
        skills.groupBy { it.categoryId }.mapValues { (_, inCategory) -> inCategory.sortedBy { it.order } }

    /** Every skill in the order the learning path walks them. */
    val path: List<Skill> = categories.sortedBy { it.order }.flatMap { skillsByCategory[it.id].orEmpty() }

    fun categoryOf(skillId: String): Category? = skillsById[skillId]?.let { categoriesById[it.categoryId] }
}

/** How an answer went the first time a question came up in a lesson. */
enum class Outcome(val xp: Int) {
    CLEAN(10),
    HINTED(5),
    WRONG(0),
}

data class AttemptState(
    val questionId: String,
    val skillId: String,
    val intervalDays: Int,
    val dueAt: Long,
    val correctStreak: Int,
    val lapses: Int,
    val timesCorrect: Int,
    val timesWrong: Int,
)

data class ReviewState(
    val questionId: String,
    val skillId: String,
    val correct: Boolean,
    val hinted: Boolean,
    val xp: Int,
    val at: Long,
)

const val DEFAULT_DAILY_GOAL = 50
val DAILY_GOALS = listOf(20, 50, 100, 200)

data class ProgressSnapshot(
    val dailyGoal: Int = DEFAULT_DAILY_GOAL,
    /** The path node whose lesson was opened last. Mixed reviews do not move it. */
    val lastSkillId: String? = null,
    val attempts: Map<String, AttemptState> = emptyMap(),
    val reviews: List<ReviewState> = emptyList(),
)
