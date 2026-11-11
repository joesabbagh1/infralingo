import Foundation

enum LessonSpec: Equatable {
    /// One node on the path.
    case skillLesson(skillId: String)

    /// A mix from every skill in a unit.
    case unitReview(categoryId: String)

    /// Whatever spaced repetition says is due, or the shakiest questions when nothing is.
    case review

    /// Questions whose last answer was a miss or needed a hint.
    case mistakes
}

enum LessonPlanner {
    static let skillSize = 6
    static let skillMin = 4
    static let mixedSize = 10
    private static let unitPerSkill = 2

    static func plan(
        spec: LessonSpec,
        bank: Bank,
        attempts: [String: AttemptState],
        now: Int64,
        rng: RNG,
    ) -> [Question] {
        switch spec {
        case .skillLesson(let skillId):
            return skill(bank.questionsBySkill[skillId] ?? [], attempts: attempts, now: now)
        case .unitReview(let categoryId):
            return unit(categoryId, bank: bank, attempts: attempts, now: now, rng: rng)
        case .review:
            return review(bank: bank, attempts: attempts, now: now, rng: rng)
        case .mistakes:
            return mistakes(bank: bank, attempts: attempts, rng: rng)
        }
    }

    static func due(bank: Bank, attempts: [String: AttemptState], now: Int64) -> [Question] {
        bank.questions
            .filter { question in attempts[question.id].map { $0.dueAt <= now } ?? false }
            .sorted { shakiestFirst(attempts)($0, $1) }
    }

    static func mistakes(bank: Bank, attempts: [String: AttemptState]) -> [Question] {
        bank.questions
            .filter { attempts[$0.id]?.memory == .learning }
            .sorted { shakiestFirst(attempts)($0, $1) }
    }

    /// Reviews that are due, then new questions from easy to hard, topped up with practice if short.
    private static func skill(
        _ questions: [Question],
        attempts: [String: AttemptState],
        now: Int64,
    ) -> [Question] {
        let partition = questions.partitioned { attempts[$0.id] != nil }
        let (seen, fresh) = partition
        let seenSplit = seen.partitioned { attempts[$0.id]!.dueAt <= now }
        let (dueQ, resting) = seenSplit
        let core = (dueQ.sorted { shakiestFirst(attempts)($0, $1) }
            + fresh.sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) })
            .prefix(skillSize)
        let practice = Array(resting.sorted { shakiestFirst(attempts)($0, $1) }.prefix(max(skillMin - core.count, 0)))
        return practice + core
    }

    private static func unit(
        _ categoryId: String,
        bank: Bank,
        attempts: [String: AttemptState],
        now: Int64,
        rng: RNG,
    ) -> [Question] {
        let shuffled = rng.shuffle((bank.skillsByCategory[categoryId] ?? []).flatMap { bank.questionsBySkill[$0.id] ?? [] })
        func rank(_ question: Question) -> Int {
            guard let attempt = attempts[question.id] else { return 2 }
            if attempt.dueAt <= now { return 0 }
            if attempt.memory == .strong { return 3 }
            return 1
        }
        // Kotlin's sort is stable, so ties keep the shuffled order: break ties with the shuffle index.
        let indexed = shuffled.enumerated().sorted {
            let (l, r) = (rank($0.element), rank($1.element))
            return l != r ? l < r : $0.offset < $1.offset
        }
        let ranked = indexed.map(\.element)

        var perSkill: [String: Int] = [:]
        var spread: [Question] = []
        for question in ranked {
            let used = perSkill[question.skillId] ?? 0
            if used < unitPerSkill {
                spread.append(question)
                perSkill[question.skillId] = used + 1
            }
        }
        let spreadIds = Set(spread.map(\.id))
        let rest = ranked.filter { !spreadIds.contains($0.id) }
        return rng.shuffle(Array((spread + rest).prefix(mixedSize)))
    }

    private static func review(
        bank: Bank,
        attempts: [String: AttemptState],
        now: Int64,
        rng: RNG,
    ) -> [Question] {
        var pool = due(bank: bank, attempts: attempts, now: now)
        if pool.isEmpty {
            pool = bank.questions.filter { attempts[$0.id] != nil }.sorted { shakiestFirst(attempts)($0, $1) }
        }
        return rng.shuffle(Array(pool.prefix(mixedSize)))
    }

    private static func mistakes(bank: Bank, attempts: [String: AttemptState], rng: RNG) -> [Question] {
        rng.shuffle(Array(mistakes(bank: bank, attempts: attempts).prefix(mixedSize)))
    }

    private static func shakiestFirst(_ attempts: [String: AttemptState]) -> (Question, Question) -> Bool {
        { lhs, rhs in
            let (a, b) = (attempts[lhs.id]!, attempts[rhs.id]!)
            if a.correctStreak != b.correctStreak { return a.correctStreak < b.correctStreak }
            if a.dueAt != b.dueAt { return a.dueAt < b.dueAt }
            return lhs.id < rhs.id
        }
    }
}

private extension Array {
    /// Splits into two lists, mirroring Kotlin's `partition`.
    func partitioned(by predicate: (Element) -> Bool) -> (matching: [Element], rest: [Element]) {
        var matching: [Element] = []
        var rest: [Element] = []
        for element in self {
            if predicate(element) { matching.append(element) } else { rest.append(element) }
        }
        return (matching, rest)
    }
}
