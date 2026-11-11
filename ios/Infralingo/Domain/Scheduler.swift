import Foundation

enum Scheduler {
    static let dayMs: Int64 = 86_400_000

    private static let ladder = [1, 3, 7, 21, 60, 120]

    static func onAnswer(
        previous: AttemptState?,
        questionId: String,
        skillId: String,
        outcome: Outcome,
        now: Int64,
    ) -> AttemptState {
        let timesCorrect = (previous?.timesCorrect ?? 0) + (outcome == .wrong ? 0 : 1)
        let timesWrong = (previous?.timesWrong ?? 0) + (outcome == .wrong ? 1 : 0)
        switch outcome {
        case .wrong:
            return AttemptState(
                questionId: questionId,
                skillId: skillId,
                intervalDays: 0,
                dueAt: now,
                correctStreak: 0,
                lapses: (previous?.lapses ?? 0) + 1,
                timesCorrect: timesCorrect,
                timesWrong: timesWrong,
            )
        case .hinted:
            // A hint means it was not recalled. Ask again tomorrow before counting it as learned.
            return AttemptState(
                questionId: questionId,
                skillId: skillId,
                intervalDays: 1,
                dueAt: now + dayMs,
                correctStreak: 0,
                lapses: previous?.lapses ?? 0,
                timesCorrect: timesCorrect,
                timesWrong: timesWrong,
            )
        case .clean:
            // Repeating a learned question before it is due is practice, not proof of recall.
            if let previous, previous.correctStreak > 0, now < previous.dueAt {
                var kept = previous
                kept.timesCorrect = timesCorrect
                return kept
            }
            let streak = (previous?.correctStreak ?? 0) + 1
            let intervalDays = ladder[min(streak, ladder.count) - 1]
            return AttemptState(
                questionId: questionId,
                skillId: skillId,
                intervalDays: intervalDays,
                dueAt: now + Int64(intervalDays) * dayMs,
                correctStreak: streak,
                lapses: previous?.lapses ?? 0,
                timesCorrect: timesCorrect,
                timesWrong: timesWrong,
            )
        }
    }

    /// A miss answered correctly later in the same lesson waits until tomorrow instead of staying due.
    static func onRetryPassed(previous: AttemptState, now: Int64) -> AttemptState {
        var next = previous
        next.intervalDays = 1
        next.dueAt = now + dayMs
        return next
    }
}
