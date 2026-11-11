import Foundation

enum ChoiceState: Equatable {
    case idle
    case selected

    /// Removed by a hint.
    case struck
    case correct
    case wrong

    /// Neither picked nor right, once the answer is showing.
    case rest
}

struct ChoiceUi: Identifiable, Equatable {
    let id: Int
    let text: String
    let state: ChoiceState
}

enum QuestionTag: Equatable {
    case new
    case review
    case mistake
    case retry
}

struct QuestionUi: Equatable {
    /// Changes every time a question is shown, including when the same one comes back.
    let key: Int
    let tag: QuestionTag
    let unitIndex: Int
    let unitTitle: String
    let skillTitle: String
    let prompt: String
    let choices: [ChoiceUi]
}

struct FeedbackUi: Equatable {
    let correct: Bool
    let title: String
    /// What happens to this question next, when that is worth saying.
    let note: String?
    let answer: String
    let explanation: String
    let xp: Int
    /// A ready-made question to hand to an assistant.
    let askAi: String
}

struct SummaryUi: Equatable {
    let title: String
    let xp: Int
    let accuracy: Int
    let seconds: Int
    let bestCombo: Int
    let streak: Int
    let streakExtended: Bool
    let todayXp: Int
    let dailyGoal: Int
    let goalReached: Bool
    /// Skills with a miss in this lesson.
    let revisit: [String]
}

struct LessonUi: Equatable {
    var progress: Double
    var combo: Int
    var question: QuestionUi
    var hintsLeft: Int
    var canCheck: Bool
    var feedback: FeedbackUi?
    var summary: SummaryUi?
}
