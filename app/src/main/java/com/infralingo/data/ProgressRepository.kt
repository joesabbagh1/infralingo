package com.infralingo.data

import com.infralingo.domain.AttemptState
import com.infralingo.domain.DAILY_GOALS
import com.infralingo.domain.DEFAULT_DAILY_GOAL
import com.infralingo.domain.Outcome
import com.infralingo.domain.ProgressSnapshot
import com.infralingo.domain.Question
import com.infralingo.domain.ReviewState
import com.infralingo.domain.Scheduler
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class ProgressRepository(private val dao: ProgressDao) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun load(): ProgressSnapshot {
        val profile = dao.profile()
        val attempts = dao.attempts().associate { it.questionId to it.toState() }
        val reviews = dao.reviews().map { it.toState() }
        return ProgressSnapshot(
            dailyGoal = profile?.dailyGoal ?: DEFAULT_DAILY_GOAL,
            lastSkillId = profile?.lastSkillId,
            attempts = attempts,
            reviews = reviews,
        )
    }

    /** Logs the first answer to a question in a lesson and reschedules it. */
    suspend fun record(question: Question, outcome: Outcome, now: Long): Pair<AttemptState, ReviewState> {
        val previous = dao.attempt(question.id)?.toState()
        val attempt = Scheduler.onAnswer(previous, question.id, question.skillId, outcome, now)
        val review = ReviewState(
            questionId = question.id,
            skillId = question.skillId,
            correct = outcome != Outcome.WRONG,
            hinted = outcome == Outcome.HINTED,
            xp = outcome.xp,
            at = now,
        )
        dao.recordAnswer(attempt.toEntity(), review.toEntity())
        return attempt to review
    }

    suspend fun recordRetryPassed(question: Question, now: Long): AttemptState? {
        val previous = dao.attempt(question.id)?.toState() ?: return null
        val attempt = Scheduler.onRetryPassed(previous, now)
        dao.upsertAttempt(attempt.toEntity())
        return attempt
    }

    suspend fun saveProfile(dailyGoal: Int, lastSkillId: String?) {
        dao.upsertProfile(ProfileEntity(dailyGoal = dailyGoal, lastSkillId = lastSkillId))
    }

    fun exportJson(snapshot: ProgressSnapshot): String {
        val bundle = ExportBundle(
            version = EXPORT_VERSION,
            dailyGoal = snapshot.dailyGoal,
            lastSkillId = snapshot.lastSkillId,
            attempts = snapshot.attempts.values.map { it.toDto() },
            reviews = snapshot.reviews.map { it.toDto() },
        )
        return json.encodeToString(bundle)
    }

    /** Replaces everything on this phone. Throws [IllegalArgumentException] when [raw] is not a usable backup. */
    suspend fun importJson(raw: String) {
        val bundle = try {
            json.decodeFromString<ExportBundle>(raw)
        } catch (error: SerializationException) {
            throw IllegalArgumentException("That file is not an Infralingo backup.", error)
        }
        require(bundle.version in 1..EXPORT_VERSION) { "That backup is from a newer Infralingo." }
        val goal = bundle.dailyGoal.takeIf { it in DAILY_GOALS } ?: DEFAULT_DAILY_GOAL
        dao.replaceAll(
            profile = ProfileEntity(dailyGoal = goal, lastSkillId = bundle.lastSkillId),
            attempts = bundle.attempts.map { it.toEntity() },
            reviews = bundle.reviews.map { it.toEntity() },
        )
    }

    private fun AttemptEntity.toState() = AttemptState(
        questionId = questionId,
        skillId = skillId,
        intervalDays = intervalDays,
        dueAt = dueAt,
        correctStreak = correctStreak,
        lapses = lapses,
        timesCorrect = timesCorrect,
        timesWrong = timesWrong,
    )

    private fun AttemptState.toEntity() = AttemptEntity(
        questionId = questionId,
        skillId = skillId,
        intervalDays = intervalDays,
        dueAt = dueAt,
        correctStreak = correctStreak,
        lapses = lapses,
        timesCorrect = timesCorrect,
        timesWrong = timesWrong,
    )

    private fun ReviewEntity.toState() = ReviewState(
        questionId = questionId,
        skillId = skillId,
        correct = correct,
        hinted = hinted,
        xp = xp,
        at = at,
    )

    private fun ReviewState.toEntity() = ReviewEntity(
        questionId = questionId,
        skillId = skillId,
        correct = correct,
        hinted = hinted,
        xp = xp,
        at = at,
    )

    private fun AttemptState.toDto() = AttemptDto(
        questionId = questionId,
        skillId = skillId,
        intervalDays = intervalDays,
        dueAt = dueAt,
        correctStreak = correctStreak,
        lapses = lapses,
        timesCorrect = timesCorrect,
        timesWrong = timesWrong,
    )

    private fun ReviewState.toDto() = ReviewDto(
        questionId = questionId,
        skillId = skillId,
        correct = correct,
        hinted = hinted,
        xp = xp,
        at = at,
    )

    private fun AttemptDto.toEntity() = AttemptEntity(
        questionId = questionId,
        skillId = skillId,
        intervalDays = intervalDays,
        dueAt = dueAt,
        correctStreak = correctStreak,
        lapses = lapses,
        timesCorrect = timesCorrect,
        timesWrong = timesWrong,
    )

    // Version 1 backups have no XP on a review. A right answer was worth a clean one.
    private fun ReviewDto.toEntity() = ReviewEntity(
        questionId = questionId,
        skillId = skillId,
        correct = correct,
        hinted = hinted,
        xp = xp ?: if (correct) Outcome.CLEAN.xp else 0,
        at = at,
    )

    private companion object {
        const val EXPORT_VERSION = 2
    }
}

@Serializable
data class ExportBundle(
    val version: Int = 1,
    val dailyGoal: Int = DEFAULT_DAILY_GOAL,
    val lastSkillId: String? = null,
    val attempts: List<AttemptDto>,
    val reviews: List<ReviewDto>,
)

@Serializable
data class AttemptDto(
    val questionId: String,
    val skillId: String,
    val intervalDays: Int,
    val dueAt: Long,
    val correctStreak: Int,
    val lapses: Int,
    val timesCorrect: Int,
    val timesWrong: Int,
)

@Serializable
data class ReviewDto(
    val questionId: String,
    val skillId: String,
    val correct: Boolean,
    val hinted: Boolean = false,
    val xp: Int? = null,
    val at: Long,
)
