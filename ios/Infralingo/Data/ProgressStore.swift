import Foundation
import SQLite3

/// The progress database, ported from the Android Room schema (version 2).
/// Access is confined to this actor, so writes are serialized in the order they were issued.
actor ProgressStore {
    enum StoreError: LocalizedError {
        case cannotOpen(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpen(let detail): return "Could not open the progress database: \(detail)"
            case .failed(let detail): return "Progress database error: \(detail)"
            }
        }
    }

    private var handle: OpaquePointer?

    /// Opens (and migrates) the database at `path`, or an in-memory one when `path` is nil.
    init(path: String?) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        var db: OpaquePointer?
        let target = path ?? ":memory:"
        guard sqlite3_open_v2(target, &db, flags, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db { sqlite3_close(db) }
            throw StoreError.cannotOpen(message)
        }
        handle = db
        try migrate()
    }

    deinit {
        if let handle { sqlite3_close(handle) }
    }

    /// Version 1 kept the streak and placement result in the profile row. Both are gone: the streak is now
    /// read from the answer log, and reviews carry the hint flag and XP that log needs. A fresh install of
    /// this port starts at version 2; the migration exists for files copied over from an Android device.
    private func migrate() throws {
        let version = Int(try scalar("PRAGMA user_version") ?? "0") ?? 0
        if version == 1 {
            // Room's MIGRATION_1_2.
            try exec("""
            ALTER TABLE reviews ADD COLUMN hinted INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE reviews ADD COLUMN xp INTEGER NOT NULL DEFAULT 0;
            UPDATE reviews SET xp = 10 WHERE correct = 1;
            DROP TABLE profile;
            CREATE TABLE profile (
                id INTEGER NOT NULL, dailyGoal INTEGER NOT NULL, lastSkillId TEXT, PRIMARY KEY(id)
            );
            """)
        }
        // Always make sure the schema is complete: it repairs a database left half-built by an
        // interrupted first run, and costs nothing when everything is already in place.
        try exec("""
        CREATE TABLE IF NOT EXISTS attempts (
            questionId TEXT NOT NULL PRIMARY KEY,
            skillId TEXT NOT NULL,
            intervalDays INTEGER NOT NULL,
            dueAt INTEGER NOT NULL,
            correctStreak INTEGER NOT NULL,
            lapses INTEGER NOT NULL,
            timesCorrect INTEGER NOT NULL,
            timesWrong INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            questionId TEXT NOT NULL,
            skillId TEXT NOT NULL,
            correct INTEGER NOT NULL,
            hinted INTEGER NOT NULL DEFAULT 0,
            xp INTEGER NOT NULL DEFAULT 0,
            at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS index_reviews_skillId ON reviews(skillId);
        CREATE INDEX IF NOT EXISTS index_reviews_at ON reviews(at);
        CREATE TABLE IF NOT EXISTS profile (
            id INTEGER NOT NULL, dailyGoal INTEGER NOT NULL, lastSkillId TEXT, PRIMARY KEY(id)
        );
        """)
        try exec("PRAGMA user_version = 2;")
    }

    // MARK: - Reads

    func attempts() throws -> [AttemptState] {
        try query("SELECT questionId, skillId, intervalDays, dueAt, correctStreak, lapses, timesCorrect, timesWrong FROM attempts") { row in
            AttemptState(
                questionId: row.text(0),
                skillId: row.text(1),
                intervalDays: row.int(2),
                dueAt: row.int64(3),
                correctStreak: row.int(4),
                lapses: row.int(5),
                timesCorrect: row.int(6),
                timesWrong: row.int(7),
            )
        }
    }

    func attempt(questionId: String) throws -> AttemptState? {
        try queryFirst(
            "SELECT questionId, skillId, intervalDays, dueAt, correctStreak, lapses, timesCorrect, timesWrong FROM attempts WHERE questionId = ?",
            bind: { $0.bindText(questionId, at: 1) },
        ) { row in
            AttemptState(
                questionId: row.text(0),
                skillId: row.text(1),
                intervalDays: row.int(2),
                dueAt: row.int64(3),
                correctStreak: row.int(4),
                lapses: row.int(5),
                timesCorrect: row.int(6),
                timesWrong: row.int(7),
            )
        }
    }

    func reviews() throws -> [ReviewState] {
        try query("SELECT questionId, skillId, correct, hinted, xp, at FROM reviews ORDER BY at ASC, id ASC") { row in
            ReviewState(
                questionId: row.text(0),
                skillId: row.text(1),
                correct: row.bool(2),
                hinted: row.bool(3),
                xp: row.int(4),
                at: row.int64(5),
            )
        }
    }

    func profile() throws -> (dailyGoal: Int, lastSkillId: String?)? {
        try queryFirst("SELECT dailyGoal, lastSkillId FROM profile WHERE id = 1") { row in
            (row.int(0), row.optText(1))
        }
    }

    // MARK: - Writes

    func upsertAttempt(_ attempt: AttemptState) throws {
        try exec(
            "INSERT OR REPLACE INTO attempts (questionId, skillId, intervalDays, dueAt, correctStreak, lapses, timesCorrect, timesWrong) VALUES (?,?,?,?,?,?,?,?)",
        ) {
            $0.bindText(attempt.questionId, at: 1)
            $0.bindText(attempt.skillId, at: 2)
            $0.bindInt(attempt.intervalDays, at: 3)
            $0.bindInt64(attempt.dueAt, at: 4)
            $0.bindInt(attempt.correctStreak, at: 5)
            $0.bindInt(attempt.lapses, at: 6)
            $0.bindInt(attempt.timesCorrect, at: 7)
            $0.bindInt(attempt.timesWrong, at: 8)
        }
    }

    func insertReview(_ review: ReviewState) throws {
        try exec(
            "INSERT INTO reviews (questionId, skillId, correct, hinted, xp, at) VALUES (?,?,?,?,?,?)",
        ) {
            $0.bindText(review.questionId, at: 1)
            $0.bindText(review.skillId, at: 2)
            $0.bindBool(review.correct, at: 3)
            $0.bindBool(review.hinted, at: 4)
            $0.bindInt(review.xp, at: 5)
            $0.bindInt64(review.at, at: 6)
        }
    }

    func upsertProfile(dailyGoal: Int, lastSkillId: String?) throws {
        try exec("INSERT OR REPLACE INTO profile (id, dailyGoal, lastSkillId) VALUES (1, ?, ?)") {
            $0.bindInt(dailyGoal, at: 1)
            $0.bindOptText(lastSkillId, at: 2)
        }
    }

    /// Logs an answer: the attempt upsert and the review insert land together or not at all.
    func recordAnswer(attempt: AttemptState, review: ReviewState) throws {
        try inTransaction {
            try self.upsertAttempt(attempt)
            try self.insertReview(review)
        }
    }

    /// Replaces everything, as an import does.
    func replaceAll(dailyGoal: Int, lastSkillId: String?, attempts: [AttemptState], reviews: [ReviewState]) throws {
        try inTransaction {
            try self.exec("DELETE FROM attempts")
            try self.exec("DELETE FROM reviews")
            try self.upsertProfile(dailyGoal: dailyGoal, lastSkillId: lastSkillId)
            for attempt in attempts { try self.upsertAttempt(attempt) }
            for review in reviews { try self.insertReview(review) }
        }
    }

    /// A no-op read, used to wait for earlier writes on this actor to land.
    func drain() async {}

    // MARK: - SQLite plumbing

    private func exec(_ sql: String, bind: ((Statement) throws -> Void)? = nil) throws {
        if let bind {
            // A bound statement can only be a single one anyway.
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement.pointer) }
            try bind(statement)
            try step(statement)
        } else {
            // sqlite3_prepare_v2 compiles only the first statement of a batch; schema SQL
            // carries several, so run the whole string through sqlite3_exec instead.
            var errorMessage: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(handle, sql, nil, nil, &errorMessage) != SQLITE_OK {
                let detail = errorMessage.map { String(cString: $0) } ?? "unknown error"
                throw StoreError.failed(detail)
            }
            if let errorMessage { sqlite3_free(errorMessage) }
        }
    }

    private func inTransaction(_ body: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            try body()
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func prepare(_ sql: String) throws -> Statement {
        var pointer: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &pointer, nil) == SQLITE_OK, let pointer else {
            throw StoreError.failed(String(cString: sqlite3_errmsg(handle)))
        }
        return Statement(pointer: pointer)
    }

    private func step(_ statement: Statement) throws {
        guard sqlite3_step(statement.pointer) == SQLITE_DONE else {
            throw StoreError.failed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    private func query<T>(_ sql: String, bind: ((Statement) throws -> Void)? = nil, read: (Statement) -> T) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement.pointer) }
        if let bind { try bind(statement) }
        var rows: [T] = []
        while sqlite3_step(statement.pointer) == SQLITE_ROW {
            rows.append(read(statement))
        }
        return rows
    }

    private func queryFirst<T>(_ sql: String, bind: ((Statement) throws -> Void)? = nil, read: (Statement) -> T) throws -> T? {
        try query(sql, bind: bind, read: read).first
    }

    private func scalar(_ sql: String) throws -> String? {
        try queryFirst(sql) { $0.text(0) }
    }

    /// A prepared statement in use: binding before stepping, column reads while a row is current.
    struct Statement {
        let pointer: OpaquePointer

        func text(_ index: Int32) -> String {
            guard let cString = sqlite3_column_text(pointer, index) else { return "" }
            return String(cString: cString)
        }

        func optText(_ index: Int32) -> String? {
            guard sqlite3_column_type(pointer, index) != SQLITE_NULL,
                  let cString = sqlite3_column_text(pointer, index)
            else { return nil }
            return String(cString: cString)
        }

        func int(_ index: Int32) -> Int { Int(sqlite3_column_int64(pointer, index)) }
        func int64(_ index: Int32) -> Int64 { sqlite3_column_int64(pointer, index) }
        func bool(_ index: Int32) -> Bool { sqlite3_column_int64(pointer, index) != 0 }

        func bindText(_ value: String, at index: Int32) {
            sqlite3_bind_text(pointer, index, value, -1, SQLITE_TRANSIENT)
        }

        func bindOptText(_ value: String?, at index: Int32) {
            if let value {
                sqlite3_bind_text(pointer, index, value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(pointer, index)
            }
        }

        func bindInt(_ value: Int, at index: Int32) {
            sqlite3_bind_int64(pointer, index, Int64(value))
        }

        func bindInt64(_ value: Int64, at index: Int32) {
            sqlite3_bind_int64(pointer, index, value)
        }

        func bindBool(_ value: Bool, at index: Int32) {
            sqlite3_bind_int64(pointer, index, value ? 1 : 0)
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
