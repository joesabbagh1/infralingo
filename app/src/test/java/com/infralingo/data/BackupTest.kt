package com.infralingo.data

import com.infralingo.domain.Difficulty
import com.infralingo.domain.Outcome
import com.infralingo.domain.Question
import com.infralingo.domain.Scheduler
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupTest {
    private class FakeDao : ProgressDao {
        val attempts = mutableMapOf<String, AttemptEntity>()
        val reviews = mutableListOf<ReviewEntity>()
        var profile: ProfileEntity? = null

        override suspend fun attempts() = attempts.values.toList()
        override suspend fun attempt(questionId: String) = attempts[questionId]
        override suspend fun reviews() = reviews.toList()
        override suspend fun profile() = profile
        override suspend fun upsertAttempt(entity: AttemptEntity) {
            attempts[entity.questionId] = entity
        }
        override suspend fun insertReview(entity: ReviewEntity) {
            reviews += entity
        }
        override suspend fun upsertProfile(entity: ProfileEntity) {
            profile = entity
        }
        override suspend fun insertAttempts(entities: List<AttemptEntity>) = entities.forEach { upsertAttempt(it) }
        override suspend fun insertReviews(entities: List<ReviewEntity>) {
            reviews += entities
        }
        override suspend fun clearAttempts() = attempts.clear()
        override suspend fun clearReviews() = reviews.clear()
    }

    private val question = Question(
        id = "q1",
        skillId = "linux-proc",
        difficulty = Difficulty.MEDIUM,
        prompt = "q1",
        choices = listOf("a", "b", "c", "d"),
        answerIndex = 0,
        explanation = "because",
    )

    @Test
    fun anAnswerIsLoggedWithItsXpAndRescheduled() = runBlocking {
        val dao = FakeDao()
        val repository = ProgressRepository(dao)
        repository.record(question, Outcome.HINTED, now = 1_000)
        repository.record(question.copy(id = "q2"), Outcome.WRONG, now = 2_000)
        repository.recordRetryPassed(question.copy(id = "q2"), now = 3_000)

        val snapshot = repository.load()
        assertEquals(listOf(5, 0), snapshot.reviews.map { it.xp })
        assertTrue(snapshot.reviews.first().hinted)
        assertEquals(1_000 + Scheduler.DAY_MS, snapshot.attempts.getValue("q1").dueAt)
        assertEquals(3_000 + Scheduler.DAY_MS, snapshot.attempts.getValue("q2").dueAt)
    }

    @Test
    fun aBackupRoundTrips() = runBlocking {
        val source = ProgressRepository(FakeDao())
        source.record(question, Outcome.CLEAN, now = 1_000)
        source.saveProfile(dailyGoal = 100, lastSkillId = "linux-proc")
        val exported = source.exportJson(source.load())

        val target = ProgressRepository(FakeDao())
        target.importJson(exported)
        assertEquals(source.load(), target.load())
    }

    @Test
    fun aVersionOneBackupStillImports() = runBlocking {
        val legacy = """
            {
              "profile": {"placementDone": true, "streak": 4, "lastSessionDay": "2026-11-10",
                          "bias": {"linux": "hard"}},
              "attempts": [{"questionId": "q1", "skillId": "linux-proc", "intervalDays": 1, "dueAt": 99,
                            "correctStreak": 1, "lapses": 0, "timesCorrect": 1, "timesWrong": 0}],
              "reviews": [{"questionId": "q1", "skillId": "linux-proc", "correct": true, "at": 5},
                          {"questionId": "q2", "skillId": "linux-proc", "correct": false, "at": 6}]
            }
        """.trimIndent()
        val repository = ProgressRepository(FakeDao())
        repository.importJson(legacy)

        val snapshot = repository.load()
        assertEquals(listOf(10, 0), snapshot.reviews.map { it.xp })
        assertEquals(1, snapshot.attempts.getValue("q1").correctStreak)
        assertEquals(50, snapshot.dailyGoal)
    }

    @Test
    fun aFileThatIsNotABackupIsRefusedAndLeavesProgressAlone() {
        val dao = FakeDao()
        val repository = ProgressRepository(dao)
        runBlocking { repository.record(question, Outcome.CLEAN, now = 1_000) }

        val unusable = listOf(
            "not json",
            """{"hello": "world"}""",
            """{"version": 99, "attempts": [], "reviews": []}""",
        )
        unusable.forEach { raw ->
            assertThrows(IllegalArgumentException::class.java) { runBlocking { repository.importJson(raw) } }
        }
        assertEquals(1, dao.reviews.size)
    }
}
