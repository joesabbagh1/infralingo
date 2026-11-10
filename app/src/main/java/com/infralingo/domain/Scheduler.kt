package com.infralingo.domain

object Scheduler {
    const val DAY_MS: Long = 86_400_000L

    private val LADDER = intArrayOf(1, 3, 7, 21, 60, 120)

    fun onAnswer(
        previous: AttemptState?,
        questionId: String,
        skillId: String,
        outcome: Outcome,
        now: Long,
    ): AttemptState {
        val timesCorrect = (previous?.timesCorrect ?: 0) + if (outcome == Outcome.WRONG) 0 else 1
        val timesWrong = (previous?.timesWrong ?: 0) + if (outcome == Outcome.WRONG) 1 else 0
        return when (outcome) {
            Outcome.WRONG -> AttemptState(
                questionId = questionId,
                skillId = skillId,
                intervalDays = 0,
                dueAt = now,
                correctStreak = 0,
                lapses = (previous?.lapses ?: 0) + 1,
                timesCorrect = timesCorrect,
                timesWrong = timesWrong,
            )
            // A hint means it was not recalled. Ask again tomorrow before counting it as learned.
            Outcome.HINTED -> AttemptState(
                questionId = questionId,
                skillId = skillId,
                intervalDays = 1,
                dueAt = now + DAY_MS,
                correctStreak = 0,
                lapses = previous?.lapses ?: 0,
                timesCorrect = timesCorrect,
                timesWrong = timesWrong,
            )
            Outcome.CLEAN -> {
                // Repeating a learned question before it is due is practice, not proof of recall.
                if (previous != null && previous.correctStreak > 0 && now < previous.dueAt) {
                    return previous.copy(timesCorrect = timesCorrect)
                }
                val streak = (previous?.correctStreak ?: 0) + 1
                val intervalDays = LADDER[minOf(streak, LADDER.size) - 1]
                AttemptState(
                    questionId = questionId,
                    skillId = skillId,
                    intervalDays = intervalDays,
                    dueAt = now + intervalDays * DAY_MS,
                    correctStreak = streak,
                    lapses = previous?.lapses ?: 0,
                    timesCorrect = timesCorrect,
                    timesWrong = timesWrong,
                )
            }
        }
    }

    /** A miss answered correctly later in the same lesson waits until tomorrow instead of staying due. */
    fun onRetryPassed(previous: AttemptState, now: Long): AttemptState =
        previous.copy(intervalDays = 1, dueAt = now + DAY_MS)
}
