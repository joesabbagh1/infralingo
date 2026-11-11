import XCTest

@testable import Infralingo

final class AppUITests: XCTestCase {
    private let day = Scheduler.dayMs
    private let utc = TimeZone(identifier: "UTC")!

    private let bank = Bank(
        categories: [
            Category(id: "linux", title: "Linux", blurb: "Host", order: 1),
            Category(id: "kubernetes", title: "Kubernetes", blurb: "Cluster", order: 2),
        ],
        skills: [
            Skill(id: "linux-proc", categoryId: "linux", title: "Processes", order: 1),
            Skill(id: "linux-signals", categoryId: "linux", title: "Signals", order: 2),
            Skill(id: "k8s-pods", categoryId: "kubernetes", title: "Pods", order: 1),
            Skill(id: "k8s-net", categoryId: "kubernetes", title: "NetworkPolicy", order: 2),
        ],
        questions: ["linux-proc", "linux-signals", "k8s-pods", "k8s-net"].flatMap { skill in
            (1 ... 2).map { n in
                Question(
                    id: "\(skill)-\(n)",
                    skillId: skill,
                    difficulty: .medium,
                    prompt: "\(skill) \(n)?",
                    choices: ["a", "b", "c", "d"],
                    answerIndex: 0,
                    explanation: "why",
                )
            }
        },
    )

    private func attempt(_ id: String, streak: Int, dueAt: Int64) -> AttemptState {
        AttemptState(
            questionId: id,
            skillId: String(id.split(separator: "-").dropLast().joined(separator: "-")),
            intervalDays: 1,
            dueAt: dueAt,
            correctStreak: streak,
            lapses: 0,
            timesCorrect: streak,
            timesWrong: 0,
        )
    }

    private func nodes(_ ui: AppUi) -> [String: NodeUi] {
        Dictionary(ui.units.flatMap(\.nodes).map { ($0.skillId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func testANewLearnerStartsAtTheFirstSkillWithEveryUnitOpen() {
        let ui = buildAppUi(bank: bank, progress: ProgressSnapshot(), now: 0, zone: utc)
        let nodes = nodes(ui)
        XCTAssertTrue(nodes["linux-proc"]!.current)
        XCTAssertEqual(NodeState.upNext, nodes["linux-proc"]!.state)
        XCTAssertEqual(NodeState.upNext, nodes["k8s-pods"]!.state)
        XCTAssertEqual(NodeState.notStarted, nodes["k8s-net"]!.state)
        XCTAssertEqual(0, ui.stats.streak)
        XCTAssertNil(ui.profile.accuracy)
        XCTAssertEqual(0, ui.practice.due)
    }

    func testThePathFollowsTheLastLessonAndShowsWhereEachSkillStands() {
        let progress = ProgressSnapshot(
            lastSkillId: "k8s-pods",
            attempts: [
                "linux-proc-1": attempt("linux-proc-1", streak: 1, dueAt: 10 * day),
                "k8s-pods-1": attempt("k8s-pods-1", streak: 3, dueAt: 10 * day),
                "k8s-pods-2": attempt("k8s-pods-2", streak: 3, dueAt: day),
                "k8s-net-1": attempt("k8s-net-1", streak: 0, dueAt: day),
            ],
            reviews: [
                ReviewState(questionId: "k8s-net-1", skillId: "k8s-net", correct: false, hinted: false, xp: 0, at: day + 5),
                ReviewState(questionId: "k8s-pods-1", skillId: "k8s-pods", correct: true, hinted: false, xp: 10, at: 2 * day + 5),
            ],
        )
        let ui = buildAppUi(bank: bank, progress: progress, now: 2 * day + 10, zone: utc)
        let nodes = nodes(ui)

        XCTAssertEqual(NodeState.mastered, nodes["k8s-pods"]!.state)
        XCTAssertEqual(1, nodes["k8s-pods"]!.due)
        XCTAssertEqual(NodeState.inProgress, nodes["k8s-net"]!.state)
        XCTAssertTrue(nodes["k8s-net"]!.current)
        XCTAssertEqual(NodeState.inProgress, nodes["linux-proc"]!.state)
        XCTAssertEqual(NodeState.upNext, nodes["linux-signals"]!.state)

        XCTAssertEqual(2, ui.stats.streak)
        XCTAssertEqual(10, ui.stats.todayXp)
        XCTAssertEqual(2, ui.practice.due)
        XCTAssertEqual(1, ui.practice.mistakes)
        XCTAssertEqual(["k8s-net 1?"], ui.profile.mistakes.map(\.prompt))
        XCTAssertEqual(3, ui.profile.learned)
        XCTAssertEqual(50, ui.profile.accuracy)
        XCTAssertEqual([false, false, false, false, false, true, true], ui.profile.week.map(\.practiced))
    }

    func testAMissedDayResetsTheStreakWithoutWaitingForTheNextLesson() {
        let progress = ProgressSnapshot(
            reviews: [
                ReviewState(questionId: "k8s-pods-1", skillId: "k8s-pods", correct: true, hinted: false, xp: 10, at: 5),
            ],
        )
        XCTAssertEqual(1, buildAppUi(bank: bank, progress: progress, now: day + 5, zone: utc).stats.streak)
        XCTAssertEqual(0, buildAppUi(bank: bank, progress: progress, now: 2 * day + 5, zone: utc).stats.streak)
    }
}
