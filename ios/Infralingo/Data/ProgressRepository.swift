import Foundation

/// Progress logic over the SQLite store: recording answers and moving snapshots in and out of backups.
struct ProgressRepository {
    let store: ProgressStore

    func load() async throws -> ProgressSnapshot {
        let profile = try await store.profile()
        let attemptRows = try await store.attempts()
        let reviewRows = try await store.reviews()
        var attempts: [String: AttemptState] = [:]
        for row in attemptRows { attempts[row.questionId] = row }
        return ProgressSnapshot(
            dailyGoal: profile?.dailyGoal ?? defaultDailyGoal,
            lastSkillId: profile?.lastSkillId,
            attempts: attempts,
            reviews: reviewRows,
        )
    }

    /// Logs the first answer to a question in a lesson and reschedules it.
    func record(_ question: Question, _ outcome: Outcome, now: Int64) async throws -> (AttemptState, ReviewState) {
        let previous = try await store.attempt(questionId: question.id)
        let attempt = Scheduler.onAnswer(
            previous: previous,
            questionId: question.id,
            skillId: question.skillId,
            outcome: outcome,
            now: now,
        )
        let review = ReviewState(
            questionId: question.id,
            skillId: question.skillId,
            correct: outcome != .wrong,
            hinted: outcome == .hinted,
            xp: outcome.xp,
            at: now,
        )
        try await store.recordAnswer(attempt: attempt, review: review)
        return (attempt, review)
    }

    func recordRetryPassed(_ question: Question, now: Int64) async throws -> AttemptState? {
        guard let previous = try await store.attempt(questionId: question.id) else { return nil }
        let attempt = Scheduler.onRetryPassed(previous: previous, now: now)
        try await store.upsertAttempt(attempt)
        return attempt
    }

    func saveProfile(dailyGoal: Int, lastSkillId: String?) async throws {
        try await store.upsertProfile(dailyGoal: dailyGoal, lastSkillId: lastSkillId)
    }

    func exportJson(_ snapshot: ProgressSnapshot) throws -> String {
        let bundle = ExportBundle(
            version: Self.exportVersion,
            dailyGoal: snapshot.dailyGoal,
            lastSkillId: snapshot.lastSkillId,
            attempts: snapshot.attempts.values.map(AttemptDto.init),
            reviews: snapshot.reviews.map(ReviewDto.init),
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Replaces everything on this phone. Throws when `raw` is not a usable backup.
    func importJson(_ raw: String) async throws {
        guard let data = raw.data(using: .utf8),
              let bundle = try? JSONDecoder().decode(ExportBundle.self, from: data)
        else {
            throw ImportError.notABackup
        }
        guard (1 ... Self.exportVersion).contains(bundle.version) else { throw ImportError.tooNew }
        let goal = dailyGoals.contains(bundle.dailyGoal) ? bundle.dailyGoal : defaultDailyGoal
        try await store.replaceAll(
            dailyGoal: goal,
            lastSkillId: bundle.lastSkillId,
            attempts: bundle.attempts.map(\.asState),
            reviews: bundle.reviews.map(\.asState),
        )
    }

    enum ImportError: LocalizedError {
        case notABackup
        case tooNew

        var errorDescription: String? {
            switch self {
            case .notABackup: return "That file is not an Infralingo backup."
            case .tooNew: return "That backup is from a newer Infralingo."
            }
        }
    }

    private static let exportVersion = 2
}

// MARK: - Backup wire format

private struct ExportBundle: Codable {
    var version: Int = 1
    var dailyGoal: Int = defaultDailyGoal
    var lastSkillId: String?
    var attempts: [AttemptDto]
    var reviews: [ReviewDto]

    private enum CodingKeys: String, CodingKey {
        case version, dailyGoal, lastSkillId, attempts, reviews
    }

    init(
        version: Int = 1,
        dailyGoal: Int = defaultDailyGoal,
        lastSkillId: String?,
        attempts: [AttemptDto],
        reviews: [ReviewDto],
    ) {
        self.version = version
        self.dailyGoal = dailyGoal
        self.lastSkillId = lastSkillId
        self.attempts = attempts
        self.reviews = reviews
    }

    /// Version 1 backups carry no version or goal; kotlinx.serialization used the defaults there.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        dailyGoal = try container.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? defaultDailyGoal
        lastSkillId = try container.decodeIfPresent(String.self, forKey: .lastSkillId)
        attempts = try container.decode([AttemptDto].self, forKey: .attempts)
        reviews = try container.decode([ReviewDto].self, forKey: .reviews)
    }
}

private struct AttemptDto: Codable {
    var questionId: String
    var skillId: String
    var intervalDays: Int
    var dueAt: Int64
    var correctStreak: Int
    var lapses: Int
    var timesCorrect: Int
    var timesWrong: Int

    init(_ state: AttemptState) {
        questionId = state.questionId
        skillId = state.skillId
        intervalDays = state.intervalDays
        dueAt = state.dueAt
        correctStreak = state.correctStreak
        lapses = state.lapses
        timesCorrect = state.timesCorrect
        timesWrong = state.timesWrong
    }

    /// Codable synthesis fills in the other constructor.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try container.decode(String.self, forKey: .questionId)
        skillId = try container.decode(String.self, forKey: .skillId)
        intervalDays = try container.decode(Int.self, forKey: .intervalDays)
        dueAt = try container.decode(Int64.self, forKey: .dueAt)
        correctStreak = try container.decode(Int.self, forKey: .correctStreak)
        lapses = try container.decode(Int.self, forKey: .lapses)
        timesCorrect = try container.decode(Int.self, forKey: .timesCorrect)
        timesWrong = try container.decode(Int.self, forKey: .timesWrong)
    }

    var asState: AttemptState {
        AttemptState(
            questionId: questionId,
            skillId: skillId,
            intervalDays: intervalDays,
            dueAt: dueAt,
            correctStreak: correctStreak,
            lapses: lapses,
            timesCorrect: timesCorrect,
            timesWrong: timesWrong,
        )
    }

    private enum CodingKeys: String, CodingKey {
        case questionId, skillId, intervalDays, dueAt, correctStreak, lapses, timesCorrect, timesWrong
    }
}

private struct ReviewDto: Codable {
    var questionId: String
    var skillId: String
    var correct: Bool
    var hinted: Bool?
    var xp: Int?
    var at: Int64

    init(_ state: ReviewState) {
        questionId = state.questionId
        skillId = state.skillId
        correct = state.correct
        hinted = state.hinted
        xp = state.xp
        at = state.at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try container.decode(String.self, forKey: .questionId)
        skillId = try container.decode(String.self, forKey: .skillId)
        correct = try container.decode(Bool.self, forKey: .correct)
        hinted = try container.decodeIfPresent(Bool.self, forKey: .hinted)
        xp = try container.decodeIfPresent(Int.self, forKey: .xp)
        at = try container.decode(Int64.self, forKey: .at)
    }

    /// Version 1 backups have no XP on a review. A right answer was worth a clean one.
    var asState: ReviewState {
        ReviewState(
            questionId: questionId,
            skillId: skillId,
            correct: correct,
            hinted: hinted ?? false,
            xp: xp ?? (correct ? Outcome.clean.xp : 0),
            at: at,
        )
    }

    private enum CodingKeys: String, CodingKey {
        case questionId, skillId, correct, hinted, xp, at
    }
}
