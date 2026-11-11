package com.infralingo.ui

enum class ChoiceState {
    IDLE,
    SELECTED,

    /** Removed by a hint. */
    STRUCK,
    CORRECT,
    WRONG,

    /** Neither picked nor right, once the answer is showing. */
    REST,
}

data class ChoiceUi(
    val text: String,
    val state: ChoiceState,
)

enum class QuestionTag { NEW, REVIEW, MISTAKE, RETRY }

data class QuestionUi(
    /** Changes every time a question is shown, including when the same one comes back. */
    val key: Int,
    val tag: QuestionTag,
    val unitIndex: Int,
    val unitTitle: String,
    val skillTitle: String,
    val prompt: String,
    val choices: List<ChoiceUi>,
)

data class FeedbackUi(
    val correct: Boolean,
    val title: String,
    /** What happens to this question next, when that is worth saying. */
    val note: String?,
    val answer: String,
    val explanation: String,
    val xp: Int,
    /** A ready-made question to hand to an assistant. */
    val askAi: String,
)

data class SummaryUi(
    val title: String,
    val xp: Int,
    val accuracy: Int,
    val seconds: Int,
    val bestCombo: Int,
    val streak: Int,
    val streakExtended: Boolean,
    val todayXp: Int,
    val dailyGoal: Int,
    val goalReached: Boolean,
    /** Skills with a miss in this lesson. */
    val revisit: List<String>,
)

data class LessonUi(
    val progress: Float,
    val combo: Int,
    val question: QuestionUi,
    val hintsLeft: Int,
    val canCheck: Boolean,
    val feedback: FeedbackUi?,
    val summary: SummaryUi?,
)
