package com.infralingo.domain

import kotlin.random.Random

sealed interface LessonSpec {
    /** One node on the path. */
    data class SkillLesson(val skillId: String) : LessonSpec

    /** A mix from every skill in a unit. */
    data class UnitReview(val categoryId: String) : LessonSpec

    /** Whatever spaced repetition says is due, or the shakiest questions when nothing is. */
    data object Review : LessonSpec

    /** Questions whose last answer was a miss or needed a hint. */
    data object Mistakes : LessonSpec
}

object LessonPlanner {
    const val SKILL_SIZE = 6
    const val SKILL_MIN = 4
    const val MIXED_SIZE = 10
    private const val UNIT_PER_SKILL = 2

    fun plan(
        spec: LessonSpec,
        bank: Bank,
        attempts: Map<String, AttemptState>,
        now: Long,
        random: Random = Random.Default,
    ): List<Question> = when (spec) {
        is LessonSpec.SkillLesson -> skill(bank.questionsBySkill[spec.skillId].orEmpty(), attempts, now)
        is LessonSpec.UnitReview -> unit(spec.categoryId, bank, attempts, now, random)
        LessonSpec.Review -> review(bank, attempts, now, random)
        LessonSpec.Mistakes -> mistakes(bank, attempts, random)
    }

    fun due(bank: Bank, attempts: Map<String, AttemptState>, now: Long): List<Question> =
        bank.questions
            .filter { question -> attempts[question.id]?.let { it.dueAt <= now } == true }
            .sortedWith(shakiestFirst(attempts))

    fun mistakes(bank: Bank, attempts: Map<String, AttemptState>): List<Question> =
        bank.questions
            .filter { attempts[it.id].memory == Memory.LEARNING }
            .sortedWith(shakiestFirst(attempts))

    /** Reviews that are due, then new questions from easy to hard, topped up with practice if short. */
    private fun skill(questions: List<Question>, attempts: Map<String, AttemptState>, now: Long): List<Question> {
        val (seen, fresh) = questions.partition { it.id in attempts }
        val (due, resting) = seen.partition { attempts.getValue(it.id).dueAt <= now }
        val core = (due.sortedWith(shakiestFirst(attempts)) + fresh.sortedWith(compareBy({ it.difficulty }, { it.id })))
            .take(SKILL_SIZE)
        val practice = resting.sortedWith(shakiestFirst(attempts)).take((SKILL_MIN - core.size).coerceAtLeast(0))
        return practice + core
    }

    private fun unit(
        categoryId: String,
        bank: Bank,
        attempts: Map<String, AttemptState>,
        now: Long,
        random: Random,
    ): List<Question> {
        val ranked = bank.skillsByCategory[categoryId].orEmpty()
            .flatMap { bank.questionsBySkill[it.id].orEmpty() }
            .shuffled(random)
            .sortedBy { question ->
                val attempt = attempts[question.id]
                when {
                    attempt == null -> 2
                    attempt.dueAt <= now -> 0
                    attempt.memory == Memory.STRONG -> 3
                    else -> 1
                }
            }
        val perSkill = mutableMapOf<String, Int>()
        val spread = ranked.filter { question ->
            val used = perSkill.getOrDefault(question.skillId, 0)
            (used < UNIT_PER_SKILL).also { if (it) perSkill[question.skillId] = used + 1 }
        }
        return (spread + (ranked - spread.toSet())).take(MIXED_SIZE).shuffled(random)
    }

    private fun review(bank: Bank, attempts: Map<String, AttemptState>, now: Long, random: Random): List<Question> {
        val due = due(bank, attempts, now)
        val pool = due.ifEmpty {
            bank.questions.filter { it.id in attempts }.sortedWith(shakiestFirst(attempts))
        }
        return pool.take(MIXED_SIZE).shuffled(random)
    }

    private fun mistakes(bank: Bank, attempts: Map<String, AttemptState>, random: Random): List<Question> =
        mistakes(bank, attempts).take(MIXED_SIZE).shuffled(random)

    private fun shakiestFirst(attempts: Map<String, AttemptState>): Comparator<Question> =
        compareBy<Question> { attempts.getValue(it.id).correctStreak }
            .thenBy { attempts.getValue(it.id).dueAt }
            .thenBy { it.id }
}
