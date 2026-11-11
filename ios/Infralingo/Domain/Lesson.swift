import Foundation

/// One showing of a question. `order` maps each position on screen to the question's own choice index.
struct LessonItem {
    let question: Question
    let order: [Int]
    let retry: Bool

    var choices: [String] { order.map { question.choices[$0] } }
    var answer: Int { order.firstIndex(of: question.answerIndex)! }
}

struct Verdict: Equatable {
    let outcome: Outcome
    let xp: Int

    var correct: Bool { outcome != .wrong }
    var hinted: Bool { outcome == .hinted }
}

/// A lesson in progress. Each question is asked until it is answered correctly, so a miss comes back at the end.
/// Only the first showing of a question earns XP, and only an unaided first answer counts toward accuracy.
struct Lesson {
    var queue: [LessonItem]
    var total: Int
    var shown: Int = 0
    var cleared: Int = 0
    var selected: Int?
    var eliminated: Set<Int> = []
    var verdict: Verdict?
    var combo: Int = 0
    var bestCombo: Int = 0
    var clean: Int = 0
    var xp: Int = 0
    var missed: [Question] = []

    var current: LessonItem? { queue.first }
    var finished: Bool { queue.isEmpty }
    var hintsLeft: Int { Self.maxHints - eliminated.count }
    var progress: Double { total == 0 ? 1 : Double(cleared) / Double(total) }

    static let maxHints = 2

    static func start(questions: [Question], rng: RNG) -> Lesson {
        Lesson(queue: questions.map { present($0, rng: rng, retry: false) }, total: questions.count)
    }

    // Choices are reshuffled on every showing so the answer cannot be learned by position.
    private static func present(_ question: Question, rng: RNG, retry: Bool) -> LessonItem {
        LessonItem(question: question, order: rng.shuffle(Array(question.choices.indices)), retry: retry)
    }

    mutating func select(_ index: Int) {
        guard let item = current else { return }
        if verdict != nil || !(item.order.indices.contains(index)) || eliminated.contains(index) { return }
        selected = index
    }

    /// Strikes out one wrong choice.
    mutating func hint(rng: RNG) {
        guard let item = current else { return }
        if verdict != nil || hintsLeft <= 0 { return }
        let candidates = item.order.indices.filter { $0 != item.answer && !eliminated.contains($0) }
        if candidates.isEmpty { return }
        guard let struck = rng.pick(candidates) else { return }
        eliminated.insert(struck)
        if selected == struck { selected = nil }
    }

    mutating func check() {
        guard let item = current, let picked = selected, verdict == nil else { return }
        let correct = picked == item.answer
        let outcome: Outcome = !correct ? .wrong : (eliminated.isEmpty ? .clean : .hinted)
        let earned = item.retry ? 0 : outcome.xp
        let nextCombo = correct ? combo + 1 : 0
        verdict = Verdict(outcome: outcome, xp: earned)
        if correct { cleared += 1 }
        combo = nextCombo
        bestCombo = max(bestCombo, nextCombo)
        if outcome == .clean && !item.retry { clean += 1 }
        xp += earned
        if !correct && !item.retry { missed.append(item.question) }
    }

    mutating func advance(rng: RNG) {
        guard let item = current, let result = verdict else { return }
        let rest = Array(queue.dropFirst())
        var again: [LessonItem] = []
        if !result.correct {
            again = [Self.present(item.question, rng: rng, retry: true)]
        }
        queue = rest + again
        shown += 1
        selected = nil
        eliminated = []
        verdict = nil
    }
}
