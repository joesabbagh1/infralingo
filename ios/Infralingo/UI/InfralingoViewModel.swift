import Foundation
import SwiftUI

@MainActor
final class InfralingoViewModel: ObservableObject {
    @Published private(set) var app = AppUi()
    @Published private(set) var lesson: LessonUi?
    @Published var notice: String?

    private var bank: Bank?
    private var snapshot = ProgressSnapshot()
    private let content: ContentRepository
    private let store: ProgressStore
    private let repository: ProgressRepository
    private var run: LessonRun?
    private let rng = RNG()

    init(content: ContentRepository, store: ProgressStore) {
        self.content = content
        self.store = store
        self.repository = ProgressRepository(store: store)
        Task { await load() }
    }

    private struct LessonRun {
        let spec: LessonSpec
        let tags: [String: QuestionTag]
        let startedAt: Int64
        /// Whether today already counted toward the streak when the lesson began.
        let practicedBefore: Bool
        var state: Lesson
    }

    private func load() async {
        do {
            // Parsing the bank is pure CPU; keep it off the main actor.
            let loaded = try await Task.detached { try self.content.load() }.value
            snapshot = try await repository.load()
            bank = loaded
            rebuild()
            // Hook for UI checks: `-autostartLesson review` or `-autostartLesson <skillId>`
            // opens that lesson immediately on launch, and `-autoanswer` plays it out slowly
            // (pick the right answer, check, advance) so each state can be screenshotted.
            if let spec = UserDefaults.standard.string(forKey: "autostartLesson") {
                start(spec == "review" ? LessonSpec.review : .skillLesson(skillId: spec))
            }
            if ProcessInfo.processInfo.arguments.contains("-autoanswer") {
                Task { await autoPlay() }
            }
        } catch {
            app = AppUi(loading: false, error: (error as? BankError)?.errorDescription ?? "\(type(of: error)): \(error.localizedDescription)")
        }
    }

    /// Due counts and the streak depend on the time, so screens ask for a fresh look when they come back.
    func refresh() {
        if bank != nil { rebuild() }
    }

    private func rebuild() {
        guard let bank else { return }
        app = buildAppUi(bank: bank, progress: snapshot, now: Date.nowMillis, zone: .current)
    }

    // MARK: - Lesson flow

    func start(_ spec: LessonSpec) {
        guard let loaded = bank, run == nil else { return }
        let now = Date.nowMillis
        let progress = snapshot
        let questions = LessonPlanner.plan(spec: spec, bank: loaded, attempts: progress.attempts, now: now, rng: rng)
        if questions.isEmpty {
            notice = "Nothing to practice here yet."
            return
        }
        let zone = TimeZone.current
        run = LessonRun(
            spec: spec,
            tags: Dictionary(
                uniqueKeysWithValues: questions.map { question in
                    let tag: QuestionTag
                    switch progress.attempts[question.id]?.memory {
                    case .new, .none: tag = .new
                    case .learning: tag = .mistake
                    case .learned, .strong: tag = .review
                    }
                    return (question.id, tag)
                },
            ),
            startedAt: now,
            practicedBefore: Activity.days(reviews: progress.reviews, zone: zone)[today(now, zone: zone)] != nil,
            state: Lesson.start(questions: questions, rng: rng),
        )
        if case .skillLesson(let skillId) = spec, skillId != progress.lastSkillId {
            snapshot.lastSkillId = skillId
            rebuild()
            Task { try? await repository.saveProfile(dailyGoal: progress.dailyGoal, lastSkillId: skillId) }
        }
        publish()
    }

    func select(_ index: Int) {
        guard var current = run else { return }
        current.state.select(index)
        run = current
        publish()
    }

    func hint() {
        guard var current = run else { return }
        current.state.hint(rng: rng)
        run = current
        publish()
    }

    func check() {
        guard let current = run, let item = current.state.current, current.state.verdict == nil else { return }
        run?.state.check()
        guard let verdict = run?.state.verdict else { return }
        let now = Date.nowMillis
        // Answers are written one at a time, in the order they were given; the store actor serializes them.
        Task {
            if !item.retry {
                if let (attempt, review) = try? await repository.record(item.question, verdict.outcome, now: now) {
                    snapshot.attempts[attempt.questionId] = attempt
                    snapshot.reviews.append(review)
                }
            } else if verdict.correct {
                if let attempt = try? await repository.recordRetryPassed(item.question, now: now) {
                    snapshot.attempts[attempt.questionId] = attempt
                }
            }
        }
        publish()
    }

    func next() {
        guard var current = run, current.state.verdict != nil else { return }
        current.state.advance(rng: rng)
        run = current
        if current.state.finished {
            finish(current)
        } else {
            publish()
        }
    }

    func close() {
        run = nil
        lesson = nil
        refresh()
    }

    func setDailyGoal(_ goal: Int) {
        let progress = snapshot
        if goal == progress.dailyGoal { return }
        snapshot.dailyGoal = goal
        rebuild()
        Task { try? await repository.saveProfile(dailyGoal: goal, lastSkillId: progress.lastSkillId) }
    }

    func exportJson() -> String {
        (try? repository.exportJson(snapshot)) ?? "{}"
    }

    func importJson(_ raw: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.importJson(raw)
                snapshot = try await repository.load()
                refresh()
                notice = "Progress replaced from the backup."
            } catch {
                notice = (error as? ProgressRepository.ImportError)?.errorDescription
                    ?? "That file is not an Infralingo backup."
            }
        }
    }

    func consumeNotice() {
        notice = nil
    }

    /// Plays the open lesson one step every two seconds, until the summary shows.
    private func autoPlay() async {
        for _ in 0 ..< 40 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if lesson?.summary != nil { return }
            guard run != nil else { return }
            if lesson?.feedback != nil {
                next()
            } else if let item = run?.state.current {
                select(item.answer)
                check()
            }
        }
    }

    private func finish(_ finished: LessonRun) {
        Task { [weak self] in
            // Let the last answer land before reading the day's totals.
            try? await self?.store.drain()
            guard let self else { return }
            let now = Date.nowMillis
            let zone = TimeZone.current
            let progress = self.snapshot
            let days = Activity.days(reviews: progress.reviews, zone: zone)
            let today = self.today(now, zone: zone)
            let todayXp = days[today]?.xp ?? 0
            let streak = Activity.streak(practiced: Set(days.keys), today: today)
            let state = finished.state
            let skills = self.bank?.skillsById ?? [:]
            self.lesson?.progress = 1
            self.lesson?.feedback = nil
            let title: String
            switch finished.spec {
            case .skillLesson: title = "Lesson complete!"
            case .unitReview: title = "Unit review complete!"
            case .review: title = "Review complete!"
            case .mistakes: title = "Mistakes reviewed!"
            }
            self.lesson?.summary = SummaryUi(
                title: title,
                xp: state.xp,
                accuracy: state.clean * 100 / max(state.total, 1),
                seconds: Int((now - finished.startedAt) / 1_000),
                bestCombo: state.bestCombo,
                streak: streak,
                streakExtended: !finished.practicedBefore && streak > 0,
                todayXp: todayXp,
                dailyGoal: progress.dailyGoal,
                goalReached: todayXp >= progress.dailyGoal && todayXp - state.xp < progress.dailyGoal,
                revisit: state.missed.map { skills[$0.skillId]?.title ?? $0.skillId }.uniqued(),
            )
        }
    }

    private func publish() {
        guard let current = run, let loaded = bank else { return }
        let state = current.state
        guard let item = state.current else { return }
        let question = item.question
        let verdict = state.verdict
        let skill = loaded.skillsById[question.skillId]
        let category = loaded.categoryOf(skillId: question.skillId)
        let choices = item.choices.enumerated().map { index, text -> ChoiceUi in
            let choiceState: ChoiceState = {
                if let verdict, index == item.answer { return .correct }
                if let verdict, index == state.selected { return .wrong }
                if state.eliminated.contains(index) { return .struck }
                if verdict != nil { return .rest }
                if index == state.selected { return .selected }
                return .idle
            }()
            return ChoiceUi(id: index, text: text, state: choiceState)
        }
        lesson = LessonUi(
            progress: state.progress,
            combo: state.combo,
            question: QuestionUi(
                key: state.shown,
                tag: item.retry ? .retry : (current.tags[question.id] ?? .new),
                unitIndex: category.flatMap { c in loaded.categories.firstIndex(where: { $0.id == c.id }) } ?? 0,
                unitTitle: category?.title ?? "",
                skillTitle: skill?.title ?? question.skillId,
                prompt: question.prompt,
                choices: choices,
            ),
            hintsLeft: state.hintsLeft,
            canCheck: state.selected != nil && verdict == nil,
            feedback: verdict.map { self.feedback($0, item: item, state: state, unit: category?.title ?? "", skill: skill?.title ?? "") },
            summary: nil,
        )
    }

    private func feedback(_ verdict: Verdict, item: LessonItem, state: Lesson, unit: String, skill: String) -> FeedbackUi {
        let question = item.question
        let answer = question.choices[question.answerIndex]
        let picked = state.selected.map { item.choices[$0] }
        let title: String
        switch (verdict.correct, item.retry, verdict.hinted) {
        case (false, _, _):
            title = item.retry ? "Still not it" : "Not quite"
        case (true, true, _):
            title = "Got it this time!"
        case (true, false, true):
            title = "Correct, with a hint"
        case (true, false, false):
            title = Self.praise[state.shown % Self.praise.count]
        }
        var note: String?
        if !verdict.correct {
            note = "This one comes back before the lesson ends."
        } else if item.retry || verdict.hinted {
            note = "You will see it again tomorrow to make sure it sticks."
        }
        var askAi = """
        I am studying DevOps and infrastructure with a quiz app. Topic: \(unit), \(skill).

        Question: \(question.prompt)

        Choices:
        """
        for choice in item.choices {
            askAi += "\n- \(choice)"
        }
        askAi += "\n\nCorrect answer: \(answer)"
        if !verdict.correct, let picked {
            askAi += "\nMy answer: \(picked)"
        }
        askAi += "\n\nExplain why the correct answer is right"
        if !verdict.correct {
            askAi += " and why mine is wrong"
        }
        askAi += ". Keep it short and practical, then give me one way to remember it."

        return FeedbackUi(
            correct: verdict.correct,
            title: title,
            note: note,
            answer: answer,
            explanation: question.explanation,
            xp: verdict.xp,
            askAi: askAi,
        )
    }

    private func today(_ now: Int64, zone: TimeZone) -> CalendarDay {
        CalendarDay(date: Date(millis: now), zone: zone)
    }

    private static let praise = ["Nicely done!", "Correct!", "Nailed it!", "Spot on!"]
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
