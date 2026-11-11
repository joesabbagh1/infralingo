package com.infralingo.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.random.Random

class LearningEngineTest {
    private val day = Scheduler.DAY_MS

    private val categories = listOf(
        Category("linux", "Linux", "Host", 1),
        Category("kubernetes", "Kubernetes", "Cluster", 2),
    )
    private val skills = listOf(
        Skill("linux-proc", "linux", "Processes", 1),
        Skill("k8s-pods", "kubernetes", "Pods", 1),
        Skill("k8s-net", "kubernetes", "NetworkPolicy", 2),
    )

    private fun question(id: String, skill: String, difficulty: Difficulty = Difficulty.MEDIUM) = Question(
        id = id,
        skillId = skill,
        difficulty = difficulty,
        prompt = id,
        choices = listOf("right", "wrong one", "wrong two", "wrong three"),
        answerIndex = 0,
        explanation = "because",
    )

    private fun attempt(id: String, skill: String, streak: Int, dueAt: Long) = AttemptState(
        questionId = id,
        skillId = skill,
        intervalDays = 1,
        dueAt = dueAt,
        correctStreak = streak,
        lapses = 0,
        timesCorrect = streak,
        timesWrong = 0,
    )

    private fun bank(questions: List<Question>) = Bank(categories, skills, questions)

    @Test
    fun cleanAnswersClimbTheIntervalLadder() {
        var state: AttemptState? = null
        val intervals = (1..7).map {
            state = Scheduler.onAnswer(state, "q", "linux-proc", Outcome.CLEAN, now = state?.dueAt ?: 0)
            state!!.intervalDays
        }
        assertEquals(listOf(1, 3, 7, 21, 60, 120, 120), intervals)
    }

    @Test
    fun aMissIsDueImmediatelyAndResetsTheStreak() {
        val known = Scheduler.onAnswer(null, "q", "linux-proc", Outcome.CLEAN, now = 0)
        val missed = Scheduler.onAnswer(known, "q", "linux-proc", Outcome.WRONG, now = 5_000)
        assertEquals(0, missed.correctStreak)
        assertEquals(5_000, missed.dueAt)
        assertEquals(1, missed.lapses)
        assertEquals(1, missed.timesCorrect)
        assertEquals(1, missed.timesWrong)
        assertEquals(Memory.LEARNING, missed.memory)
    }

    @Test
    fun aHintedAnswerComesBackTomorrowAndIsNotLearned() {
        val strong = attempt("q", "linux-proc", streak = 4, dueAt = 0)
        val hinted = Scheduler.onAnswer(strong, "q", "linux-proc", Outcome.HINTED, now = 1_000)
        assertEquals(0, hinted.correctStreak)
        assertEquals(1_000 + day, hinted.dueAt)
        assertEquals(0, hinted.lapses)
        assertEquals(Memory.LEARNING, hinted.memory)
    }

    @Test
    fun repeatingALearnedQuestionBeforeItIsDueDoesNotAdvanceIt() {
        val learned = Scheduler.onAnswer(null, "q", "linux-proc", Outcome.CLEAN, now = 0)
        val crammed = Scheduler.onAnswer(learned, "q", "linux-proc", Outcome.CLEAN, now = 60_000)
        assertEquals(learned.correctStreak, crammed.correctStreak)
        assertEquals(learned.dueAt, crammed.dueAt)
        assertEquals(2, crammed.timesCorrect)
    }

    @Test
    fun aRetryPassMovesAMissToTomorrowWithoutCountingItLearned() {
        val missed = Scheduler.onAnswer(null, "q", "linux-proc", Outcome.WRONG, now = 0)
        val retried = Scheduler.onRetryPassed(missed, now = 30_000)
        assertEquals(30_000 + day, retried.dueAt)
        assertEquals(Memory.LEARNING, retried.memory)
    }

    @Test
    fun skillProgressCountsWhatIsLearnedStrongAndDue() {
        val questions = (1..4).map { question("q$it", "linux-proc") }
        val attempts = mapOf(
            "q1" to attempt("q1", "linux-proc", streak = 3, dueAt = 50),
            "q2" to attempt("q2", "linux-proc", streak = 1, dueAt = 500),
            "q3" to attempt("q3", "linux-proc", streak = 0, dueAt = 10),
        )
        val progress = Mastery.skill("linux-proc", questions, attempts, now = 100)
        assertEquals(SkillProgress("linux-proc", total = 4, seen = 3, learned = 2, strong = 1, due = 2), progress)
        assertFalse(progress.complete)
        val all = questions.associate { it.id to attempt(it.id, "linux-proc", streak = 3, dueAt = 500) }
        assertTrue(Mastery.skill("linux-proc", questions, all, now = 100).mastered)
    }

    @Test
    fun recentAccuracyIgnoresHintedAnswers() {
        val reviews = listOf(
            ReviewState("q1", "linux-proc", correct = true, hinted = false, xp = 10, at = 1),
            ReviewState("q2", "linux-proc", correct = true, hinted = true, xp = 5, at = 2),
            ReviewState("q3", "linux-proc", correct = false, hinted = false, xp = 0, at = 3),
            ReviewState("q4", "linux-proc", correct = true, hinted = false, xp = 10, at = 4),
        )
        val accuracy = Mastery.recentAccuracy(reviews)
        assertEquals(SkillAccuracy("linux-proc", answers = 4, percent = 50), accuracy["linux-proc"])
    }

    @Test
    fun streakCountsBackFromTodayAndSurvivesUntilTheDayEnds() {
        val today = LocalDate.parse("2026-11-10")
        val practiced = setOf("2026-11-10", "2026-11-09", "2026-11-08", "2026-11-05").map(LocalDate::parse).toSet()
        assertEquals(3, Activity.streak(practiced, today))
        assertEquals(3, Activity.streak(practiced, today.plusDays(1)))
        assertEquals(0, Activity.streak(practiced, today.plusDays(2)))
        assertEquals(0, Activity.streak(emptySet(), today))
    }

    @Test
    fun dailyTotalsComeFromTheAnswerLog() {
        val reviews = listOf(
            ReviewState("q1", "linux-proc", correct = true, hinted = false, xp = 10, at = 0),
            ReviewState("q2", "linux-proc", correct = true, hinted = true, xp = 5, at = 1_000),
            ReviewState("q3", "linux-proc", correct = false, hinted = false, xp = 0, at = day + 1),
        )
        val days = Activity.days(reviews, ZoneOffset.UTC)
        assertEquals(Day(LocalDate.parse("1970-01-01"), xp = 15, answers = 2), days[LocalDate.parse("1970-01-01")])
        assertEquals(0, days.getValue(LocalDate.parse("1970-01-02")).xp)
    }

    @Test
    fun aSkillLessonAsksWhatIsDueThenNewQuestionsFromEasyToHard() {
        val questions = listOf(
            question("a-hard", "linux-proc", Difficulty.HARD),
            question("b-easy", "linux-proc", Difficulty.EASY),
            question("c-medium", "linux-proc", Difficulty.MEDIUM),
            question("d-due", "linux-proc"),
            question("e-resting", "linux-proc"),
            question("other", "k8s-pods"),
        )
        val attempts = mapOf(
            "d-due" to attempt("d-due", "linux-proc", streak = 1, dueAt = 50),
            "e-resting" to attempt("e-resting", "linux-proc", streak = 1, dueAt = 5_000),
        )
        val lesson = LessonPlanner.plan(LessonSpec.SkillLesson("linux-proc"), bank(questions), attempts, now = 100)
        assertEquals(listOf("d-due", "b-easy", "c-medium", "a-hard"), lesson.map { it.id })
    }

    @Test
    fun aSkillLessonIsCappedAndAShortOneIsToppedUpWithPractice() {
        val many = (1..9).map { question("q$it", "linux-proc") }
        assertEquals(
            LessonPlanner.SKILL_SIZE,
            LessonPlanner.plan(LessonSpec.SkillLesson("linux-proc"), bank(many), emptyMap(), now = 0).size,
        )

        val resting = many.take(8).associate { it.id to attempt(it.id, "linux-proc", streak = 1, dueAt = 5_000) }
        val topped = LessonPlanner.plan(LessonSpec.SkillLesson("linux-proc"), bank(many), resting, now = 100)
        assertEquals(LessonPlanner.SKILL_MIN, topped.size)
        assertEquals("q9", topped.last().id)
    }

    @Test
    fun reviewServesWhatIsDueAndFallsBackToTheShakiestWhenNothingIs() {
        val questions = (1..14).map { question("q%02d".format(it), if (it % 2 == 0) "linux-proc" else "k8s-pods") }
        val attempts = questions.take(12).associate { it.id to attempt(it.id, it.skillId, streak = 2, dueAt = 5_000) } +
            mapOf(
                "q01" to attempt("q01", "k8s-pods", streak = 1, dueAt = 10),
                "q02" to attempt("q02", "linux-proc", streak = 0, dueAt = 20),
            )
        val due = LessonPlanner.plan(LessonSpec.Review, bank(questions), attempts, now = 100, Random(1))
        assertEquals(setOf("q01", "q02"), due.map { it.id }.toSet())

        val nothingDue = LessonPlanner.plan(LessonSpec.Review, bank(questions), attempts, now = 5, Random(1))
        assertEquals(LessonPlanner.MIXED_SIZE, nothingDue.size)
        assertTrue(nothingDue.all { it.id in attempts })
        assertTrue(nothingDue.map { it.id }.containsAll(listOf("q01", "q02")))
    }

    @Test
    fun mistakesServeOnlyQuestionsThatAreStillBeingLearned() {
        val questions = (1..4).map { question("q$it", "linux-proc") }
        val attempts = mapOf(
            "q1" to attempt("q1", "linux-proc", streak = 0, dueAt = 9_000),
            "q2" to attempt("q2", "linux-proc", streak = 2, dueAt = 10),
        )
        val lesson = LessonPlanner.plan(LessonSpec.Mistakes, bank(questions), attempts, now = 100)
        assertEquals(listOf("q1"), lesson.map { it.id })
    }

    @Test
    fun aUnitReviewSpreadsAcrossTheSkillsOfThatUnit() {
        val questions = (1..12).map { question("pods-$it", "k8s-pods") } +
            (1..12).map { question("net-$it", "k8s-net") } +
            (1..12).map { question("linux-$it", "linux-proc") }
        val lesson = LessonPlanner.plan(LessonSpec.UnitReview("kubernetes"), bank(questions), emptyMap(), 0, Random(7))
        assertEquals(LessonPlanner.MIXED_SIZE, lesson.size)
        assertEquals(lesson.size, lesson.distinct().size)
        assertTrue(lesson.none { it.skillId == "linux-proc" })
        assertTrue(lesson.count { it.skillId == "k8s-pods" } >= 2)
        assertTrue(lesson.count { it.skillId == "k8s-net" } >= 2)
    }

    @Test
    fun aLessonShufflesChoicesAndKeepsTrackOfTheAnswer() {
        val lesson = Lesson.start((1..20).map { question("q$it", "linux-proc") }, Random(3))
        assertTrue(lesson.queue.all { it.choices[it.answer] == "right" })
        assertTrue(lesson.queue.map { it.answer }.distinct().size > 1)
    }

    @Test
    fun aMissedQuestionComesBackUntilItIsRightAndOnlyTheFirstTryScores() {
        val random = Random(5)
        var lesson = Lesson.start(listOf(question("q1", "linux-proc"), question("q2", "linux-proc")), random)

        val wrong = (0..3).first { it != lesson.current!!.answer }
        lesson = lesson.select(wrong).check()
        assertEquals(Outcome.WRONG, lesson.verdict!!.outcome)
        assertEquals(0f, lesson.progress)
        lesson = lesson.advance(random)

        lesson = lesson.select(lesson.current!!.answer).check()
        assertEquals(Outcome.CLEAN, lesson.verdict!!.outcome)
        assertEquals(10, lesson.verdict!!.xp)
        lesson = lesson.advance(random)

        val again = lesson.current!!
        assertTrue(again.retry)
        assertEquals("q1", again.question.id)
        lesson = lesson.select(again.answer).check()
        assertEquals(0, lesson.verdict!!.xp)
        lesson = lesson.advance(random)

        assertTrue(lesson.finished)
        assertEquals(1f, lesson.progress)
        assertEquals(1, lesson.clean)
        assertEquals(10, lesson.xp)
        assertEquals(listOf("q1"), lesson.missed.map { it.id })
        assertEquals(2, lesson.bestCombo)
    }

    @Test
    fun aHintStrikesWrongChoicesOnlyAndHalvesTheReward() {
        val random = Random(11)
        var lesson = Lesson.start(listOf(question("q1", "linux-proc")), random)
        val answer = lesson.current!!.answer
        val wrong = (0..3).first { it != answer }

        lesson = lesson.select(wrong).hint(random).hint(random).hint(random)
        assertEquals(Lesson.MAX_HINTS, lesson.eliminated.size)
        assertFalse(answer in lesson.eliminated)
        assertEquals(0, lesson.hintsLeft)
        if (wrong in lesson.eliminated) assertNull(lesson.selected)

        assertEquals(lesson, lesson.select(lesson.eliminated.first()))
        lesson = lesson.select(answer).check()
        assertEquals(Outcome.HINTED, lesson.verdict!!.outcome)
        assertEquals(5, lesson.verdict!!.xp)
        assertEquals(0, lesson.clean)
    }

    @Test
    fun nothingIsCheckedUntilAChoiceIsPicked() {
        val lesson = Lesson.start(listOf(question("q1", "linux-proc")), Random(2))
        assertNull(lesson.check().verdict)
        assertEquals(lesson, lesson.advance())
    }
}
