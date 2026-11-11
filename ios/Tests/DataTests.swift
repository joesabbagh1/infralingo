import XCTest

@testable import Infralingo

final class BackupTests: XCTestCase {
    private let question = Question(
        id: "q1",
        skillId: "linux-proc",
        difficulty: .medium,
        prompt: "q1",
        choices: ["a", "b", "c", "d"],
        answerIndex: 0,
        explanation: "because",
    )

    private func makeRepository() throws -> ProgressRepository {
        ProgressRepository(store: try ProgressStore(path: nil))
    }

    func testAnAnswerIsLoggedWithItsXpAndRescheduled() async throws {
        let repository = try makeRepository()
        _ = try await repository.record(question, .hinted, now: 1_000)
        _ = try await repository.record(
            Question(id: "q2", skillId: "linux-proc", difficulty: .medium, prompt: "q2", choices: ["a", "b", "c", "d"], answerIndex: 0, explanation: "because"),
            .wrong,
            now: 2_000,
        )
        _ = try await repository.recordRetryPassed(
            Question(id: "q2", skillId: "linux-proc", difficulty: .medium, prompt: "q2", choices: ["a", "b", "c", "d"], answerIndex: 0, explanation: "because"),
            now: 3_000,
        )

        let snapshot = try await repository.load()
        XCTAssertEqual([5, 0], snapshot.reviews.map(\.xp))
        XCTAssertTrue(snapshot.reviews.first!.hinted)
        XCTAssertEqual(1_000 + Scheduler.dayMs, snapshot.attempts["q1"]!.dueAt)
        XCTAssertEqual(3_000 + Scheduler.dayMs, snapshot.attempts["q2"]!.dueAt)
    }

    func testABackupRoundTrips() async throws {
        let source = try makeRepository()
        _ = try await source.record(question, .clean, now: 1_000)
        try await source.saveProfile(dailyGoal: 100, lastSkillId: "linux-proc")
        let exported = try source.exportJson(try await source.load())

        let target = try makeRepository()
        try await target.importJson(exported)
        let sourceSnapshot = try await source.load()
        let targetSnapshot = try await target.load()
        XCTAssertEqual(sourceSnapshot, targetSnapshot)
    }

    func testAVersionOneBackupStillImports() async throws {
        let legacy = """
        {
          "profile": {"placementDone": true, "streak": 4, "lastSessionDay": "2026-11-10",
                      "bias": {"linux": "hard"}},
          "attempts": [{"questionId": "q1", "skillId": "linux-proc", "intervalDays": 1, "dueAt": 99,
                        "correctStreak": 1, "lapses": 0, "timesCorrect": 1, "timesWrong": 0}],
          "reviews": [{"questionId": "q1", "skillId": "linux-proc", "correct": true, "at": 5},
                      {"questionId": "q2", "skillId": "linux-proc", "correct": false, "at": 6}]
        }
        """
        let repository = try makeRepository()
        try await repository.importJson(legacy)

        let snapshot = try await repository.load()
        XCTAssertEqual([10, 0], snapshot.reviews.map(\.xp))
        XCTAssertEqual(1, snapshot.attempts["q1"]!.correctStreak)
        XCTAssertEqual(50, snapshot.dailyGoal)
    }

    func testAFileThatIsNotABackupIsRefusedAndLeavesProgressAlone() async throws {
        let repository = try makeRepository()
        _ = try await repository.record(question, .clean, now: 1_000)

        let unusable = [
            "not json",
            #"{"hello": "world"}"#,
            #"{"version": 99, "attempts": [], "reviews": []}"#,
        ]
        for raw in unusable {
            do {
                try await repository.importJson(raw)
                XCTFail("Expected \(raw) to be refused")
            } catch {
                // Refused, as it should be.
            }
        }
        let snapshot = try await repository.load()
        XCTAssertEqual(1, snapshot.reviews.count)
    }
}

final class BankIntegrityTests: XCTestCase {
    func testBundledBankMeetsTheSkillFloor() throws {
        let bundle = Bundle(for: BankIntegrityTests.self)
        func read(_ name: String) throws -> String {
            guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "content")
            else { throw BankError.invalid("Missing bundled file content/\(name)") }
            return try String(contentsOf: url, encoding: .utf8)
        }
        let manifest = try read("manifest.json")
        let categories = try read("categories.json")
        let skills = try read("skills.json")
        let files = try BankJSON.parseManifest(manifest).map { name in
            try read("questions/\(name)")
        }
        let bank = try BankJSON.parse(categoriesJson: categories, skillsJson: skills, questionJsons: files)
        XCTAssertTrue(bank.questions.count >= 400)
        XCTAssertTrue(bank.categories.count >= 10)
    }
}
