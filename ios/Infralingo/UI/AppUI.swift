import Foundation

struct TopStats: Equatable {
    var streak: Int = 0
    var practicedToday: Bool = false
    var todayXp: Int = 0
    var dailyGoal: Int = defaultDailyGoal
    var totalXp: Int = 0
}

enum NodeState: Equatable {
    case notStarted
    case upNext
    case inProgress
    case complete
    case mastered
}

struct NodeUi: Identifiable, Equatable {
    var id: String { skillId }
    let skillId: String
    let title: String
    let state: NodeState
    let learned: Int
    let total: Int
    let due: Int
    /// The one node the path suggests doing next.
    let current: Bool
}

struct UnitUi: Identifiable, Equatable {
    let id: String
    /// Position on the path. It also picks the unit's colour.
    let index: Int
    let title: String
    let blurb: String
    let learned: Int
    let total: Int
    let nodes: [NodeUi]

    var started: Bool { nodes.contains { $0.state != .notStarted && $0.state != .upNext } }
    var complete: Bool { total > 0 && learned == total }
}

struct SkillLink: Equatable {
    let skillId: String
    let title: String
    let unitTitle: String
    let unitIndex: Int
    let percent: Int
}

struct PracticeUi: Equatable {
    var due: Int = 0
    /// Milliseconds until the next review comes due, when none is due now.
    var nextDueIn: Int64?
    var seen: Int = 0
    var mistakes: Int = 0
    var weakSpots: [SkillLink] = []
}

struct DayUi: Equatable {
    let label: String
    let practiced: Bool
    let today: Bool
}

struct MistakeUi: Equatable {
    let questionId: String
    let prompt: String
    let skillTitle: String
}

struct ProfileUi: Equatable {
    var answered: Int = 0
    var accuracy: Int?
    var learned: Int = 0
    var questions: Int = 0
    var week: [DayUi] = []
    var strengths: [SkillLink] = []
    var mistakes: [MistakeUi] = []
}

struct AppUi: Equatable {
    var loading: Bool = true
    var error: String?
    var stats: TopStats = TopStats()
    var units: [UnitUi] = []
    var practice: PracticeUi = PracticeUi()
    var profile: ProfileUi = ProfileUi()
}

private let weakBelow = 70
private let strongFrom = 80

func buildAppUi(bank: Bank, progress: ProgressSnapshot, now: Int64, zone: TimeZone) -> AppUi {
    let today = CalendarDay(date: Date(millis: now), zone: zone)
    let skills = Mastery.all(bank: bank, attempts: progress.attempts, now: now)
    let days = Activity.days(reviews: progress.reviews, zone: zone)
    var unitIndex: [String: Int] = [:]
    for (index, category) in bank.categories.enumerated() { unitIndex[category.id] = index }

    // Pick up at the last lesson opened: the first unfinished skill from there on, wrapping to the start.
    let path = bank.path
    let last = max(path.firstIndex { $0.id == progress.lastSkillId } ?? -1, 0)
    let reordered = Array(path[last...]) + Array(path[..<last])
    let current = reordered.first { !skills[$0.id]!.complete }?.id

    let units = bank.categories.enumerated().map { index, category -> UnitUi in
        let inUnit = bank.skillsByCategory[category.id] ?? []
        let entry = inUnit.first { !skills[$0.id]!.started }?.id
        let nodes = inUnit.map { skill -> NodeUi in
            let mine = skills[skill.id]!
            let state: NodeState = {
                if mine.mastered { return .mastered }
                if mine.complete { return .complete }
                if mine.started { return .inProgress }
                if skill.id == entry || skill.id == current { return .upNext }
                return .notStarted
            }()
            return NodeUi(
                skillId: skill.id,
                title: skill.title,
                state: state,
                learned: mine.learned,
                total: mine.total,
                due: mine.due,
                current: skill.id == current,
            )
        }
        return UnitUi(
            id: category.id,
            index: index,
            title: category.title,
            blurb: category.blurb,
            learned: nodes.reduce(0) { $0 + $1.learned },
            total: nodes.reduce(0) { $0 + $1.total },
            nodes: nodes,
        )
    }

    func link(_ skillId: String, _ percent: Int) -> SkillLink? {
        guard let skill = bank.skillsById[skillId], let category = bank.categoriesById[skill.categoryId]
        else { return nil }
        return SkillLink(skillId: skillId, title: skill.title, unitTitle: category.title, unitIndex: unitIndex[category.id]!, percent: percent)
    }

    let accuracy = Mastery.recentAccuracy(reviews: progress.reviews).values
    let weakSpots = accuracy
        .filter { $0.answers >= 3 && $0.percent < weakBelow }
        .sorted { ($0.percent, $0.skillId) < ($1.percent, $1.skillId) }
        .compactMap { link($0.skillId, $0.percent) }
        .prefix(3)
    let strengths = accuracy
        .filter { $0.answers >= 5 && $0.percent >= strongFrom }
        .sorted { lhs, rhs in
            // Highest percent first, ties broken by id ascending.
            lhs.percent != rhs.percent ? lhs.percent > rhs.percent : lhs.skillId < rhs.skillId
        }
        .compactMap { link($0.skillId, $0.percent) }
        .prefix(3)

    let known = progress.attempts.filter { bank.questionsById[$0.key] != nil }
    let mistakeQuestions = LessonPlanner.mistakes(bank: bank, attempts: progress.attempts)
    let reviews = progress.reviews
    let week: [DayUi] = (0 ... 6).reversed().map { back -> DayUi in
        let date = today.adding(days: -back)
        return DayUi(
            label: date.narrowWeekday(zone: zone),
            practiced: days[date] != nil,
            today: back == 0,
        )
    }

    let learnedTotal = units.reduce(0) { $0 + $1.learned }

    return AppUi(
        loading: false,
        stats: TopStats(
            streak: Activity.streak(practiced: Set(days.keys), today: today),
            practicedToday: days[today] != nil,
            todayXp: days[today]?.xp ?? 0,
            dailyGoal: progress.dailyGoal,
            totalXp: reviews.reduce(0) { $0 + $1.xp },
        ),
        units: units,
        practice: PracticeUi(
            due: known.values.filter { $0.dueAt <= now }.count,
            nextDueIn: known.values.filter { $0.dueAt > now }.map { $0.dueAt - now }.min(),
            seen: known.count,
            mistakes: mistakeQuestions.count,
            weakSpots: Array(weakSpots),
        ),
        profile: ProfileUi(
            answered: reviews.count,
            accuracy: reviews.isEmpty ? nil : reviews.filter { $0.correct && !$0.hinted }.count * 100 / reviews.count,
            learned: learnedTotal,
            questions: bank.questions.count,
            week: week,
            strengths: Array(strengths),
            mistakes: mistakeQuestions
                .sorted { (progress.attempts[$0.id]!.dueAt) > (progress.attempts[$1.id]!.dueAt) }
                .prefix(8)
                .map { MistakeUi(questionId: $0.id, prompt: $0.prompt, skillTitle: bank.skillsById[$0.skillId]?.title ?? $0.skillId) },
        ),
    )
}
