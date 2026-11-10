package com.infralingo.domain

import kotlin.random.Random

/** One showing of a question. [order] maps each position on screen to the question's own choice index. */
data class LessonItem(
    val question: Question,
    val order: List<Int>,
    val retry: Boolean = false,
) {
    val choices: List<String> get() = order.map { question.choices[it] }
    val answer: Int get() = order.indexOf(question.answerIndex)
}

data class Verdict(
    val outcome: Outcome,
    val xp: Int,
) {
    val correct: Boolean get() = outcome != Outcome.WRONG
    val hinted: Boolean get() = outcome == Outcome.HINTED
}

/**
 * A lesson in progress. Each question is asked until it is answered correctly, so a miss comes back at the end.
 * Only the first showing of a question earns XP, and only an unaided first answer counts toward accuracy.
 */
data class Lesson(
    val queue: List<LessonItem>,
    val total: Int,
    val shown: Int = 0,
    val cleared: Int = 0,
    val selected: Int? = null,
    val eliminated: Set<Int> = emptySet(),
    val verdict: Verdict? = null,
    val combo: Int = 0,
    val bestCombo: Int = 0,
    val clean: Int = 0,
    val xp: Int = 0,
    val missed: List<Question> = emptyList(),
) {
    val current: LessonItem? get() = queue.firstOrNull()
    val finished: Boolean get() = queue.isEmpty()
    val hintsLeft: Int get() = MAX_HINTS - eliminated.size
    val progress: Float get() = if (total == 0) 1f else cleared.toFloat() / total

    fun select(index: Int): Lesson {
        val item = current ?: return this
        if (verdict != null || index !in item.order.indices || index in eliminated) return this
        return copy(selected = index)
    }

    /** Strikes out one wrong choice. */
    fun hint(random: Random = Random.Default): Lesson {
        val item = current ?: return this
        if (verdict != null || hintsLeft <= 0) return this
        val candidates = item.order.indices.filter { it != item.answer && it !in eliminated }
        if (candidates.isEmpty()) return this
        val struck = candidates.random(random)
        return copy(eliminated = eliminated + struck, selected = selected.takeIf { it != struck })
    }

    fun check(): Lesson {
        val item = current ?: return this
        val picked = selected ?: return this
        if (verdict != null) return this
        val correct = picked == item.answer
        val outcome = when {
            !correct -> Outcome.WRONG
            eliminated.isNotEmpty() -> Outcome.HINTED
            else -> Outcome.CLEAN
        }
        val earned = if (item.retry) 0 else outcome.xp
        val nextCombo = if (correct) combo + 1 else 0
        return copy(
            verdict = Verdict(outcome, earned),
            cleared = cleared + if (correct) 1 else 0,
            combo = nextCombo,
            bestCombo = maxOf(bestCombo, nextCombo),
            clean = clean + if (outcome == Outcome.CLEAN && !item.retry) 1 else 0,
            xp = xp + earned,
            missed = if (!correct && !item.retry) missed + item.question else missed,
        )
    }

    fun advance(random: Random = Random.Default): Lesson {
        val item = current ?: return this
        val result = verdict ?: return this
        val rest = queue.drop(1)
        val again = if (result.correct) emptyList() else listOf(present(item.question, random, retry = true))
        return copy(
            queue = rest + again,
            shown = shown + 1,
            selected = null,
            eliminated = emptySet(),
            verdict = null,
        )
    }

    companion object {
        const val MAX_HINTS = 2

        fun start(questions: List<Question>, random: Random = Random.Default): Lesson =
            Lesson(queue = questions.map { present(it, random, retry = false) }, total = questions.size)

        // Choices are reshuffled on every showing so the answer cannot be learned by position.
        private fun present(question: Question, random: Random, retry: Boolean) =
            LessonItem(question, question.choices.indices.shuffled(random), retry)
    }
}
