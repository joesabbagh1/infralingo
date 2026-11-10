package com.infralingo.ui

import com.infralingo.domain.AttemptState
import com.infralingo.domain.Bank
import com.infralingo.domain.Category
import com.infralingo.domain.Difficulty
import com.infralingo.domain.ProgressSnapshot
import com.infralingo.domain.Question
import com.infralingo.domain.ReviewState
import com.infralingo.domain.Scheduler
import com.infralingo.domain.Skill
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneOffset

class AppUiTest {
    private val day = Scheduler.DAY_MS

    private val bank = Bank(
        categories = listOf(Category("linux", "Linux", "Host", 1), Category("kubernetes", "Kubernetes", "Cluster", 2)),
        skills = listOf(
            Skill("linux-proc", "linux", "Processes", 1),
            Skill("linux-signals", "linux", "Signals", 2),
            Skill("k8s-pods", "kubernetes", "Pods", 1),
            Skill("k8s-net", "kubernetes", "NetworkPolicy", 2),
        ),
        questions = listOf("linux-proc", "linux-signals", "k8s-pods", "k8s-net").flatMap { skill ->
            (1..2).map { n ->
                val choices = listOf("a", "b", "c", "d")
                Question("$skill-$n", skill, Difficulty.MEDIUM, "$skill $n?", choices, 0, "why", "test", "")
            }
        },
    )

    private fun attempt(id: String, streak: Int, dueAt: Long) =
        AttemptState(id, id.substringBeforeLast('-'), 1, dueAt, streak, 0, streak, 0)

    private fun nodes(ui: AppUi) = ui.units.flatMap { it.nodes }.associateBy { it.skillId }

    @Test
    fun aNewLearnerStartsAtTheFirstSkillWithEveryUnitOpen() {
        val ui = buildAppUi(bank, ProgressSnapshot(), now = 0, ZoneOffset.UTC)
        val nodes = nodes(ui)
        assertTrue(nodes.getValue("linux-proc").current)
        assertEquals(NodeState.UP_NEXT, nodes.getValue("linux-proc").state)
        assertEquals(NodeState.UP_NEXT, nodes.getValue("k8s-pods").state)
        assertEquals(NodeState.NOT_STARTED, nodes.getValue("k8s-net").state)
        assertEquals(0, ui.stats.streak)
        assertNull(ui.profile.accuracy)
        assertEquals(0, ui.practice.due)
    }

    @Test
    fun thePathFollowsTheLastLessonAndShowsWhereEachSkillStands() {
        val progress = ProgressSnapshot(
            lastSkillId = "k8s-pods",
            attempts = mapOf(
                "linux-proc-1" to attempt("linux-proc-1", streak = 1, dueAt = 10 * day),
                "k8s-pods-1" to attempt("k8s-pods-1", streak = 3, dueAt = 10 * day),
                "k8s-pods-2" to attempt("k8s-pods-2", streak = 3, dueAt = day),
                "k8s-net-1" to attempt("k8s-net-1", streak = 0, dueAt = day),
            ),
            reviews = listOf(
                ReviewState("k8s-net-1", "k8s-net", correct = false, hinted = false, xp = 0, at = day + 5),
                ReviewState("k8s-pods-1", "k8s-pods", correct = true, hinted = false, xp = 10, at = 2 * day + 5),
            ),
        )
        val ui = buildAppUi(bank, progress, now = 2 * day + 10, ZoneOffset.UTC)
        val nodes = nodes(ui)

        assertEquals(NodeState.MASTERED, nodes.getValue("k8s-pods").state)
        assertEquals(1, nodes.getValue("k8s-pods").due)
        assertEquals(NodeState.IN_PROGRESS, nodes.getValue("k8s-net").state)
        assertTrue(nodes.getValue("k8s-net").current)
        assertEquals(NodeState.IN_PROGRESS, nodes.getValue("linux-proc").state)
        assertEquals(NodeState.UP_NEXT, nodes.getValue("linux-signals").state)

        assertEquals(2, ui.stats.streak)
        assertEquals(10, ui.stats.todayXp)
        assertEquals(2, ui.practice.due)
        assertEquals(1, ui.practice.mistakes)
        assertEquals(listOf("k8s-net 1?"), ui.profile.mistakes.map { it.prompt })
        assertEquals(3, ui.profile.learned)
        assertEquals(50, ui.profile.accuracy)
        assertEquals(listOf(false, false, false, false, false, true, true), ui.profile.week.map { it.practiced })
    }

    @Test
    fun aMissedDayResetsTheStreakWithoutWaitingForTheNextLesson() {
        val progress = ProgressSnapshot(
            reviews = listOf(ReviewState("k8s-pods-1", "k8s-pods", correct = true, hinted = false, xp = 10, at = 5)),
        )
        assertEquals(1, buildAppUi(bank, progress, now = day + 5, ZoneOffset.UTC).stats.streak)
        assertEquals(0, buildAppUi(bank, progress, now = 2 * day + 5, ZoneOffset.UTC).stats.streak)
    }
}
