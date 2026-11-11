import Foundation

/// What the app believes about one question.
enum Memory: Equatable {
    case new

    /// Seen, but the last answer was a miss or needed a hint.
    case learning

    /// Answered unaided since the last miss.
    case learned

    /// Recalled unaided across several spaced reviews.
    case strong
}

extension AttemptState {
    var memory: Memory {
        if correctStreak == 0 { return .learning }
        if correctStreak < Mastery.strongStreak { return .learned }
        return .strong
    }
}

extension Optional where Wrapped == AttemptState {
    var memory: Memory {
        self?.memory ?? .new
    }
}

struct SkillProgress: Equatable {
    var skillId: String
    var total: Int
    var seen: Int
    /// Includes the strong ones.
    var learned: Int
    var strong: Int
    var due: Int

    var started: Bool { seen > 0 }
    var complete: Bool { total > 0 && learned == total }
    var mastered: Bool { total > 0 && strong == total }
}

struct SkillAccuracy: Equatable {
    var skillId: String
    var answers: Int
    var percent: Int
}

enum Mastery {
    static let strongStreak = 3

    static func skill(
        skillId: String,
        questions: [Question],
        attempts: [String: AttemptState],
        now: Int64,
    ) -> SkillProgress {
        var seen = 0
        var learned = 0
        var strong = 0
        var due = 0
        for question in questions {
            guard let attempt = attempts[question.id] else { continue }
            seen += 1
            if attempt.dueAt <= now { due += 1 }
            switch attempt.memory {
            case .strong:
                learned += 1
                strong += 1
            case .learned:
                learned += 1
            case .new, .learning:
                break
            }
        }
        return SkillProgress(skillId: skillId, total: questions.count, seen: seen, learned: learned, strong: strong, due: due)
    }

    static func all(bank: Bank, attempts: [String: AttemptState], now: Int64) -> [String: SkillProgress] {
        Dictionary(
            bank.skills.map { skill in
                (skill.id, Self.skill(skillId: skill.id, questions: bank.questionsBySkill[skill.id] ?? [], attempts: attempts, now: now))
            },
            uniquingKeysWith: { a, _ in a },
        )
    }

    /// Share of each skill's latest answers that were right with no hint.
    static func recentAccuracy(reviews: [ReviewState], window: Int = 10) -> [String: SkillAccuracy] {
        Dictionary(grouping: reviews, by: \.skillId)
            .mapValues { mine -> SkillAccuracy in
                let recent = Array(mine.suffix(window))
                let unaided = recent.filter { $0.correct && !$0.hinted }.count
                return SkillAccuracy(skillId: mine[0].skillId, answers: recent.count, percent: unaided * 100 / recent.count)
            }
    }
}
