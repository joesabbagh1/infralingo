package com.infralingo.domain

/** What the app believes about one question. */
enum class Memory {
    NEW,

    /** Seen, but the last answer was a miss or needed a hint. */
    LEARNING,

    /** Answered unaided since the last miss. */
    LEARNED,

    /** Recalled unaided across several spaced reviews. */
    STRONG,
}

val AttemptState?.memory: Memory
    get() = when {
        this == null -> Memory.NEW
        correctStreak == 0 -> Memory.LEARNING
        correctStreak < Mastery.STRONG_STREAK -> Memory.LEARNED
        else -> Memory.STRONG
    }

data class SkillProgress(
    val skillId: String,
    val total: Int,
    val seen: Int,
    /** Includes the strong ones. */
    val learned: Int,
    val strong: Int,
    val due: Int,
) {
    val started: Boolean get() = seen > 0
    val complete: Boolean get() = total > 0 && learned == total
    val mastered: Boolean get() = total > 0 && strong == total
}

data class SkillAccuracy(
    val skillId: String,
    val answers: Int,
    val percent: Int,
)

object Mastery {
    const val STRONG_STREAK = 3

    fun skill(
        skillId: String,
        questions: List<Question>,
        attempts: Map<String, AttemptState>,
        now: Long,
    ): SkillProgress {
        var seen = 0
        var learned = 0
        var strong = 0
        var due = 0
        for (question in questions) {
            val attempt = attempts[question.id] ?: continue
            seen += 1
            if (attempt.dueAt <= now) due += 1
            when (attempt.memory) {
                Memory.STRONG -> {
                    learned += 1
                    strong += 1
                }
                Memory.LEARNED -> learned += 1
                else -> Unit
            }
        }
        return SkillProgress(skillId, questions.size, seen, learned, strong, due)
    }

    fun all(bank: Bank, attempts: Map<String, AttemptState>, now: Long): Map<String, SkillProgress> =
        bank.skills.associate { skill ->
            skill.id to skill(skill.id, bank.questionsBySkill[skill.id].orEmpty(), attempts, now)
        }

    /** Share of each skill's latest answers that were right with no hint. */
    fun recentAccuracy(reviews: List<ReviewState>, window: Int = 10): Map<String, SkillAccuracy> =
        reviews.groupBy { it.skillId }.mapValues { (skillId, mine) ->
            val recent = mine.takeLast(window)
            val unaided = recent.count { it.correct && !it.hinted }
            SkillAccuracy(skillId, recent.size, unaided * 100 / recent.size)
        }
}
