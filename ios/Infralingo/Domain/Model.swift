import Foundation

enum Difficulty: Int, Comparable {
    case easy = 0
    case medium = 1
    case hard = 2

    static func parse(_ raw: String) -> Difficulty {
        switch raw.lowercased() {
        case "easy": return .easy
        case "medium": return .medium
        case "hard": return .hard
        default: fatalError("Unknown difficulty: \(raw)")
        }
    }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Category: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let order: Int
}

struct Skill: Identifiable, Hashable {
    let id: String
    let categoryId: String
    let title: String
    let order: Int
}

struct Question: Identifiable, Hashable {
    let id: String
    let skillId: String
    let difficulty: Difficulty
    let prompt: String
    let choices: [String]
    let answerIndex: Int
    let explanation: String
}

struct Bank {
    let categories: [Category]
    let skills: [Skill]
    let questions: [Question]

    let categoriesById: [String: Category]
    let skillsById: [String: Skill]
    let questionsById: [String: Question]
    let questionsBySkill: [String: [Question]]
    let skillsByCategory: [String: [Skill]]

    /// Every skill in the order the learning path walks them.
    let path: [Skill]

    init(categories: [Category], skills: [Skill], questions: [Question]) {
        self.categories = categories
        self.skills = skills
        self.questions = questions
        self.categoriesById = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.skillsById = Dictionary(skills.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.questionsById = Dictionary(questions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.questionsBySkill = Dictionary(grouping: questions, by: \.skillId)
        var byCategory = Dictionary(grouping: skills, by: \.categoryId)
        byCategory = byCategory.mapValues { $0.sorted { $0.order < $1.order } }
        self.skillsByCategory = byCategory
        self.path = categories.sorted { $0.order < $1.order }.flatMap { byCategory[$0.id] ?? [] }
    }

    func categoryOf(skillId: String) -> Category? {
        skillsById[skillId].flatMap { categoriesById[$0.categoryId] }
    }
}

/// How an answer went the first time a question came up in a lesson.
enum Outcome: Int {
    case clean = 0
    case hinted = 1
    case wrong = 2

    var xp: Int {
        switch self {
        case .clean: return 10
        case .hinted: return 5
        case .wrong: return 0
        }
    }
}

struct AttemptState: Equatable {
    var questionId: String
    var skillId: String
    var intervalDays: Int
    var dueAt: Int64
    var correctStreak: Int
    var lapses: Int
    var timesCorrect: Int
    var timesWrong: Int
}

struct ReviewState: Equatable {
    var questionId: String
    var skillId: String
    var correct: Bool
    var hinted: Bool
    var xp: Int
    var at: Int64
}

let defaultDailyGoal = 50
let dailyGoals = [20, 50, 100, 200]

struct ProgressSnapshot: Equatable {
    var dailyGoal: Int = defaultDailyGoal
    /// The path node whose lesson was opened last. Mixed reviews do not move it.
    var lastSkillId: String?
    var attempts: [String: AttemptState] = [:]
    var reviews: [ReviewState] = []
}

extension Int64 {
    var milliseconds: TimeInterval { TimeInterval(self) / 1_000 }
}

extension Date {
    var millis: Int64 { Int64(timeIntervalSince1970 * 1_000) }

    static var nowMillis: Int64 { Date().millis }
}
