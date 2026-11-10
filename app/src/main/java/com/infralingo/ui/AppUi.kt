package com.infralingo.ui

import com.infralingo.domain.Activity
import com.infralingo.domain.Bank
import com.infralingo.domain.DEFAULT_DAILY_GOAL
import com.infralingo.domain.LessonPlanner
import com.infralingo.domain.Mastery
import com.infralingo.domain.ProgressSnapshot
import java.time.Instant
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

data class TopStats(
    val streak: Int = 0,
    val practicedToday: Boolean = false,
    val todayXp: Int = 0,
    val dailyGoal: Int = DEFAULT_DAILY_GOAL,
    val totalXp: Int = 0,
)

enum class NodeState { NOT_STARTED, UP_NEXT, IN_PROGRESS, COMPLETE, MASTERED }

data class NodeUi(
    val skillId: String,
    val title: String,
    val state: NodeState,
    val learned: Int,
    val total: Int,
    val due: Int,
    /** The one node the path suggests doing next. */
    val current: Boolean,
)

data class UnitUi(
    val id: String,
    /** Position on the path. It also picks the unit's colour. */
    val index: Int,
    val title: String,
    val blurb: String,
    val learned: Int,
    val total: Int,
    val nodes: List<NodeUi>,
) {
    val started: Boolean get() = nodes.any { it.state != NodeState.NOT_STARTED && it.state != NodeState.UP_NEXT }
    val complete: Boolean get() = total > 0 && learned == total
}

data class SkillLink(
    val skillId: String,
    val title: String,
    val unitTitle: String,
    val unitIndex: Int,
    val percent: Int,
)

data class PracticeUi(
    val due: Int = 0,
    /** Milliseconds until the next review comes due, when none is due now. */
    val nextDueIn: Long? = null,
    val seen: Int = 0,
    val mistakes: Int = 0,
    val weakSpots: List<SkillLink> = emptyList(),
)

data class DayUi(
    val label: String,
    val practiced: Boolean,
    val today: Boolean,
)

data class MistakeUi(
    val questionId: String,
    val prompt: String,
    val skillTitle: String,
)

data class ProfileUi(
    val answered: Int = 0,
    val accuracy: Int? = null,
    val learned: Int = 0,
    val questions: Int = 0,
    val week: List<DayUi> = emptyList(),
    val strengths: List<SkillLink> = emptyList(),
    val mistakes: List<MistakeUi> = emptyList(),
)

data class AppUi(
    val loading: Boolean = true,
    val error: String? = null,
    val stats: TopStats = TopStats(),
    val units: List<UnitUi> = emptyList(),
    val practice: PracticeUi = PracticeUi(),
    val profile: ProfileUi = ProfileUi(),
)

private const val WEAK_BELOW = 70
private const val STRONG_FROM = 80

fun buildAppUi(bank: Bank, progress: ProgressSnapshot, now: Long, zone: ZoneId): AppUi {
    val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
    val skills = Mastery.all(bank, progress.attempts, now)
    val days = Activity.days(progress.reviews, zone)
    val unitIndex = bank.categories.withIndex().associate { it.value.id to it.index }

    // Pick up at the last lesson opened: the first unfinished skill from there on, wrapping to the start.
    val path = bank.path
    val last = path.indexOfFirst { it.id == progress.lastSkillId }.coerceAtLeast(0)
    val current = (path.drop(last) + path.take(last)).firstOrNull { !skills.getValue(it.id).complete }?.id

    val units = bank.categories.mapIndexed { index, category ->
        val inUnit = bank.skillsByCategory[category.id].orEmpty()
        val entry = inUnit.firstOrNull { !skills.getValue(it.id).started }?.id
        val nodes = inUnit.map { skill ->
            val mine = skills.getValue(skill.id)
            NodeUi(
                skillId = skill.id,
                title = skill.title,
                state = when {
                    mine.mastered -> NodeState.MASTERED
                    mine.complete -> NodeState.COMPLETE
                    mine.started -> NodeState.IN_PROGRESS
                    skill.id == entry || skill.id == current -> NodeState.UP_NEXT
                    else -> NodeState.NOT_STARTED
                },
                learned = mine.learned,
                total = mine.total,
                due = mine.due,
                current = skill.id == current,
            )
        }
        UnitUi(
            id = category.id,
            index = index,
            title = category.title,
            blurb = category.blurb,
            learned = nodes.sumOf { it.learned },
            total = nodes.sumOf { it.total },
            nodes = nodes,
        )
    }

    fun link(skillId: String, percent: Int): SkillLink? {
        val skill = bank.skillsById[skillId] ?: return null
        val category = bank.categoriesById[skill.categoryId] ?: return null
        return SkillLink(skillId, skill.title, category.title, unitIndex.getValue(category.id), percent)
    }

    val accuracy = Mastery.recentAccuracy(progress.reviews).values
    val weakSpots = accuracy
        .filter { it.answers >= 3 && it.percent < WEAK_BELOW }
        .sortedWith(compareBy({ it.percent }, { it.skillId }))
        .mapNotNull { link(it.skillId, it.percent) }
        .take(3)
    val strengths = accuracy
        .filter { it.answers >= 5 && it.percent >= STRONG_FROM }
        .sortedWith(compareBy({ -it.percent }, { it.skillId }))
        .mapNotNull { link(it.skillId, it.percent) }
        .take(3)

    val known = progress.attempts.filterKeys { it in bank.questionsById }
    val mistakes = LessonPlanner.mistakes(bank, progress.attempts)
    val reviews = progress.reviews
    val week = (6 downTo 0L).map { back ->
        val date = today.minusDays(back)
        DayUi(
            label = date.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault()),
            practiced = date in days,
            today = back == 0L,
        )
    }

    return AppUi(
        loading = false,
        stats = TopStats(
            streak = Activity.streak(days.keys, today),
            practicedToday = today in days,
            todayXp = days[today]?.xp ?: 0,
            dailyGoal = progress.dailyGoal,
            totalXp = reviews.sumOf { it.xp },
        ),
        units = units,
        practice = PracticeUi(
            due = known.values.count { it.dueAt <= now },
            nextDueIn = known.values.filter { it.dueAt > now }.minOfOrNull { it.dueAt - now },
            seen = known.size,
            mistakes = mistakes.size,
            weakSpots = weakSpots,
        ),
        profile = ProfileUi(
            answered = reviews.size,
            accuracy = if (reviews.isEmpty()) null else reviews.count { it.correct && !it.hinted } * 100 / reviews.size,
            learned = units.sumOf { it.learned },
            questions = bank.questions.size,
            week = week,
            strengths = strengths,
            mistakes = mistakes
                .sortedByDescending { progress.attempts.getValue(it.id).dueAt }
                .take(8)
                .map { MistakeUi(it.id, it.prompt, bank.skillsById[it.skillId]?.title ?: it.skillId) },
        ),
    )
}
