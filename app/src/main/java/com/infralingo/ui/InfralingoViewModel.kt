package com.infralingo.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.infralingo.InfralingoApplication
import com.infralingo.data.ContentRepository
import com.infralingo.data.ProgressRepository
import com.infralingo.domain.Activity
import com.infralingo.domain.Bank
import com.infralingo.domain.Lesson
import com.infralingo.domain.LessonItem
import com.infralingo.domain.LessonPlanner
import com.infralingo.domain.LessonSpec
import com.infralingo.domain.Memory
import com.infralingo.domain.ProgressSnapshot
import com.infralingo.domain.Verdict
import com.infralingo.domain.memory
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId

class InfralingoViewModel(
    private val content: ContentRepository,
    private val store: ProgressRepository,
) : ViewModel() {
    private val bank = MutableStateFlow<Bank?>(null)
    private val snapshot = MutableStateFlow(ProgressSnapshot())
    private val clock = MutableStateFlow(System.currentTimeMillis())
    private val failure = MutableStateFlow<String?>(null)

    // Answers are written one at a time, in the order they were given.
    private val writes = Mutex()
    private var run: LessonRun? = null

    val app: StateFlow<AppUi> = combine(bank, snapshot, clock, failure) { loaded, progress, now, error ->
        when {
            error != null -> AppUi(loading = false, error = error)
            loaded == null -> AppUi()
            else -> buildAppUi(loaded, progress, now, ZoneId.systemDefault())
        }
    }.flowOn(Dispatchers.Default).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppUi())

    private val _lesson = MutableStateFlow<LessonUi?>(null)
    val lesson: StateFlow<LessonUi?> = _lesson.asStateFlow()

    private val _notice = MutableStateFlow<String?>(null)
    val notice: StateFlow<String?> = _notice.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                val loaded = withContext(Dispatchers.IO) { content.load() }
                snapshot.value = store.load()
                bank.value = loaded
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                failure.value = error.message ?: "Could not load the question bank"
            }
        }
    }

    /** Due counts and the streak depend on the time, so screens ask for a fresh look when they come back. */
    fun refresh() {
        clock.value = System.currentTimeMillis()
    }

    fun start(spec: LessonSpec) {
        val loaded = bank.value ?: return
        if (run != null) return
        val now = System.currentTimeMillis()
        val progress = snapshot.value
        val questions = LessonPlanner.plan(spec, loaded, progress.attempts, now)
        if (questions.isEmpty()) {
            _notice.value = "Nothing to practice here yet."
            return
        }
        val zone = ZoneId.systemDefault()
        run = LessonRun(
            spec = spec,
            tags = questions.associate { question ->
                question.id to when (progress.attempts[question.id].memory) {
                    Memory.NEW -> QuestionTag.NEW
                    Memory.LEARNING -> QuestionTag.MISTAKE
                    else -> QuestionTag.REVIEW
                }
            },
            startedAt = now,
            practicedBefore = today(now, zone) in Activity.days(progress.reviews, zone),
            state = Lesson.start(questions),
        )
        if (spec is LessonSpec.SkillLesson && spec.skillId != progress.lastSkillId) {
            snapshot.update { it.copy(lastSkillId = spec.skillId) }
            viewModelScope.launch { store.saveProfile(progress.dailyGoal, spec.skillId) }
        }
        publish()
    }

    fun select(index: Int) {
        val current = run ?: return
        current.state = current.state.select(index)
        publish()
    }

    fun hint() {
        val current = run ?: return
        current.state = current.state.hint()
        publish()
    }

    fun check() {
        val current = run ?: return
        val item = current.state.current ?: return
        if (current.state.verdict != null) return
        val checked = current.state.check()
        val verdict = checked.verdict ?: return
        current.state = checked
        val now = System.currentTimeMillis()
        viewModelScope.launch {
            writes.withLock {
                if (!item.retry) {
                    val (attempt, review) = store.record(item.question, verdict.outcome, now)
                    snapshot.update {
                        it.copy(attempts = it.attempts + (attempt.questionId to attempt), reviews = it.reviews + review)
                    }
                } else if (verdict.correct) {
                    val attempt = store.recordRetryPassed(item.question, now) ?: return@withLock
                    snapshot.update { it.copy(attempts = it.attempts + (attempt.questionId to attempt)) }
                }
            }
        }
        publish()
    }

    fun next() {
        val current = run ?: return
        if (current.state.verdict == null) return
        current.state = current.state.advance()
        if (current.state.finished) finish(current) else publish()
    }

    fun close() {
        run = null
        _lesson.value = null
        refresh()
    }

    fun setDailyGoal(goal: Int) {
        val progress = snapshot.value
        if (goal == progress.dailyGoal) return
        snapshot.update { it.copy(dailyGoal = goal) }
        viewModelScope.launch { store.saveProfile(goal, progress.lastSkillId) }
    }

    fun exportJson(): String = store.exportJson(snapshot.value)

    fun importJson(raw: String) {
        viewModelScope.launch {
            try {
                writes.withLock {
                    store.importJson(raw)
                    snapshot.value = store.load()
                }
                refresh()
                _notice.value = "Progress replaced from the backup."
            } catch (error: IllegalArgumentException) {
                _notice.value = error.message ?: "That file is not an Infralingo backup."
            }
        }
    }

    fun notify(message: String) {
        _notice.value = message
    }

    fun consumeNotice() {
        _notice.value = null
    }

    private fun finish(finished: LessonRun) {
        viewModelScope.launch {
            // Let the last answer land before reading the day's totals.
            writes.withLock { }
            val now = System.currentTimeMillis()
            val zone = ZoneId.systemDefault()
            val progress = snapshot.value
            val days = Activity.days(progress.reviews, zone)
            val today = today(now, zone)
            val todayXp = days[today]?.xp ?: 0
            val streak = Activity.streak(days.keys, today)
            val state = finished.state
            val skills = bank.value?.skillsById.orEmpty()
            _lesson.update { shown ->
                shown?.copy(
                    progress = 1f,
                    feedback = null,
                    summary = SummaryUi(
                        title = when (finished.spec) {
                            is LessonSpec.SkillLesson -> "Lesson complete!"
                            is LessonSpec.UnitReview -> "Unit review complete!"
                            LessonSpec.Review -> "Review complete!"
                            LessonSpec.Mistakes -> "Mistakes reviewed!"
                        },
                        xp = state.xp,
                        accuracy = state.clean * 100 / state.total.coerceAtLeast(1),
                        seconds = ((now - finished.startedAt) / 1000).toInt(),
                        bestCombo = state.bestCombo,
                        streak = streak,
                        streakExtended = !finished.practicedBefore && streak > 0,
                        todayXp = todayXp,
                        dailyGoal = progress.dailyGoal,
                        goalReached = todayXp >= progress.dailyGoal && todayXp - state.xp < progress.dailyGoal,
                        revisit = state.missed.map { skills[it.skillId]?.title ?: it.skillId }.distinct(),
                    ),
                )
            }
        }
    }

    private fun publish() {
        val current = run ?: return
        val loaded = bank.value ?: return
        val state = current.state
        val item = state.current ?: return
        val question = item.question
        val verdict = state.verdict
        val skill = loaded.skillsById[question.skillId]
        val category = loaded.categoryOf(question.skillId)
        _lesson.value = LessonUi(
            progress = state.progress,
            combo = state.combo,
            question = QuestionUi(
                key = state.shown,
                tag = if (item.retry) QuestionTag.RETRY else current.tags[question.id] ?: QuestionTag.NEW,
                unitIndex = loaded.categories.indexOf(category).coerceAtLeast(0),
                unitTitle = category?.title.orEmpty(),
                skillTitle = skill?.title ?: question.skillId,
                prompt = question.prompt,
                choices = item.choices.mapIndexed { index, text ->
                    ChoiceUi(
                        text = text,
                        state = when {
                            verdict != null && index == item.answer -> ChoiceState.CORRECT
                            verdict != null && index == state.selected -> ChoiceState.WRONG
                            index in state.eliminated -> ChoiceState.STRUCK
                            verdict != null -> ChoiceState.REST
                            index == state.selected -> ChoiceState.SELECTED
                            else -> ChoiceState.IDLE
                        },
                    )
                },
            ),
            hintsLeft = state.hintsLeft,
            canCheck = state.selected != null && verdict == null,
            feedback = verdict?.let { feedback(it, item, state, category?.title.orEmpty(), skill?.title.orEmpty()) },
            summary = null,
        )
    }

    private fun feedback(verdict: Verdict, item: LessonItem, state: Lesson, unit: String, skill: String): FeedbackUi {
        val question = item.question
        val answer = question.choices[question.answerIndex]
        val picked = state.selected?.let { item.choices[it] }
        return FeedbackUi(
            correct = verdict.correct,
            title = when {
                !verdict.correct -> if (item.retry) "Still not it" else "Not quite"
                item.retry -> "Got it this time!"
                verdict.hinted -> "Correct, with a hint"
                else -> PRAISE[state.shown % PRAISE.size]
            },
            note = when {
                !verdict.correct -> "This one comes back before the lesson ends."
                item.retry || verdict.hinted -> "You will see it again tomorrow to make sure it sticks."
                else -> null
            },
            answer = answer,
            explanation = question.explanation,
            source = question.source,
            url = question.url,
            xp = verdict.xp,
            askAi = buildString {
                appendLine("I am studying DevOps and infrastructure with a quiz app. Topic: $unit, $skill.")
                appendLine()
                appendLine("Question: ${question.prompt}")
                appendLine()
                appendLine("Choices:")
                item.choices.forEach { appendLine("- $it") }
                appendLine()
                appendLine("Correct answer: $answer")
                if (!verdict.correct && picked != null) appendLine("My answer: $picked")
                appendLine()
                append("Explain why the correct answer is right")
                if (!verdict.correct) append(" and why mine is wrong")
                append(". Keep it short and practical, then give me one way to remember it.")
            },
        )
    }

    private fun today(now: Long, zone: ZoneId) = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()

    private class LessonRun(
        val spec: LessonSpec,
        val tags: Map<String, QuestionTag>,
        val startedAt: Long,
        /** Whether today already counted toward the streak when the lesson began. */
        val practicedBefore: Boolean,
        var state: Lesson,
    )

    companion object {
        private val PRAISE = listOf("Nicely done!", "Correct!", "Nailed it!", "Spot on!")

        fun factory(application: InfralingoApplication): ViewModelProvider.Factory = viewModelFactory {
            initializer { InfralingoViewModel(application.contentRepository, application.progressRepository) }
        }
    }
}
