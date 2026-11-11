import XCTest

@testable import Infralingo

final class LearningEngineTests: XCTestCase {
    private let day = Scheduler.dayMs

    private let categories = [
        Category(id: "linux", title: "Linux", blurb: "Host", order: 1),
        Category(id: "kubernetes", title: "Kubernetes", blurb: "Cluster", order: 2),
    ]
    private let skills = [
        Skill(id: "linux-proc", categoryId: "linux", title: "Processes", order: 1),
        Skill(id: "k8s-pods", categoryId: "kubernetes", title: "Pods", order: 1),
        Skill(id: "k8s-net", categoryId: "kubernetes", title: "NetworkPolicy", order: 2),
    ]

    private func question(_ id: String, _ skill: String, difficulty: Difficulty = .medium) -> Question {
        Question(
            id: id,
            skillId: skill,
            difficulty: difficulty,
            prompt: id,
            choices: ["right", "wrong one", "wrong two", "wrong three"],
            answerIndex: 0,
            explanation: "because",
        )
    }

    private func attempt(_ id: String, _ skill: String, streak: Int, dueAt: Int64) -> AttemptState {
        AttemptState(
            questionId: id,
            skillId: skill,
            intervalDays: 1,
            dueAt: dueAt,
            correctStreak: streak,
            lapses: 0,
            timesCorrect: streak,
            timesWrong: 0,
        )
    }

    private func bank(_ questions: [Question]) -> Bank {
        Bank(categories: categories, skills: skills, questions: questions)
    }

    func testCleanAnswersClimbTheIntervalLadder() {
        var state: AttemptState?
        var intervals: [Int] = []
        for _ in 0 ..< 7 {
            state = Scheduler.onAnswer(
                previous: state,
                questionId: "q",
                skillId: "linux-proc",
                outcome: .clean,
                now: state?.dueAt ?? 0,
            )
            intervals.append(state!.intervalDays)
        }
        XCTAssertEqual([1, 3, 7, 21, 60, 120, 120], intervals)
    }

    func testAMissIsDueImmediatelyAndResetsTheStreak() {
        let known = Scheduler.onAnswer(previous: nil, questionId: "q", skillId: "linux-proc", outcome: .clean, now: 0)
        let missed = Scheduler.onAnswer(previous: known, questionId: "q", skillId: "linux-proc", outcome: .wrong, now: 5_000)
        XCTAssertEqual(0, missed.correctStreak)
        XCTAssertEqual(5_000, missed.dueAt)
        XCTAssertEqual(1, missed.lapses)
        XCTAssertEqual(1, missed.timesCorrect)
        XCTAssertEqual(1, missed.timesWrong)
        XCTAssertEqual(Memory.learning, Optional(missed).memory)
    }

    func testAHintedAnswerComesBackTomorrowAndIsNotLearned() {
        let strong = attempt("q", "linux-proc", streak: 4, dueAt: 0)
        let hinted = Scheduler.onAnswer(previous: strong, questionId: "q", skillId: "linux-proc", outcome: .hinted, now: 1_000)
        XCTAssertEqual(0, hinted.correctStreak)
        XCTAssertEqual(1_000 + day, hinted.dueAt)
        XCTAssertEqual(0, hinted.lapses)
        XCTAssertEqual(Memory.learning, Optional(hinted).memory)
    }

    func testRepeatingALearnedQuestionBeforeItIsDueDoesNotAdvanceIt() {
        let learned = Scheduler.onAnswer(previous: nil, questionId: "q", skillId: "linux-proc", outcome: .clean, now: 0)
        let crammed = Scheduler.onAnswer(previous: learned, questionId: "q", skillId: "linux-proc", outcome: .clean, now: 60_000)
        XCTAssertEqual(learned.correctStreak, crammed.correctStreak)
        XCTAssertEqual(learned.dueAt, crammed.dueAt)
        XCTAssertEqual(2, crammed.timesCorrect)
    }

    func testARetryPassMovesAMissToTomorrowWithoutCountingItLearned() {
        let missed = Scheduler.onAnswer(previous: nil, questionId: "q", skillId: "linux-proc", outcome: .wrong, now: 0)
        let retried = Scheduler.onRetryPassed(previous: missed, now: 30_000)
        XCTAssertEqual(30_000 + day, retried.dueAt)
        XCTAssertEqual(Memory.learning, Optional(retried).memory)
    }

    func testSkillProgressCountsWhatIsLearnedStrongAndDue() {
        let questions = (1 ... 4).map { question("q\($0)", "linux-proc") }
        let attempts: [String: AttemptState] = [
            "q1": attempt("q1", "linux-proc", streak: 3, dueAt: 50),
            "q2": attempt("q2", "linux-proc", streak: 1, dueAt: 500),
            "q3": attempt("q3", "linux-proc", streak: 0, dueAt: 10),
        ]
        let progress = Mastery.skill(skillId: "linux-proc", questions: questions, attempts: attempts, now: 100)
        XCTAssertEqual(
            SkillProgress(skillId: "linux-proc", total: 4, seen: 3, learned: 2, strong: 1, due: 2),
            progress,
        )
        XCTAssertFalse(progress.complete)
        let all = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, attempt($0.id, "linux-proc", streak: 3, dueAt: 500)) })
        XCTAssertTrue(Mastery.skill(skillId: "linux-proc", questions: questions, attempts: all, now: 100).mastered)
    }

    func testRecentAccuracyIgnoresHintedAnswers() {
        let reviews = [
            ReviewState(questionId: "q1", skillId: "linux-proc", correct: true, hinted: false, xp: 10, at: 1),
            ReviewState(questionId: "q2", skillId: "linux-proc", correct: true, hinted: true, xp: 5, at: 2),
            ReviewState(questionId: "q3", skillId: "linux-proc", correct: false, hinted: false, xp: 0, at: 3),
            ReviewState(questionId: "q4", skillId: "linux-proc", correct: true, hinted: false, xp: 10, at: 4),
        ]
        let accuracy = Mastery.recentAccuracy(reviews: reviews)
        XCTAssertEqual(SkillAccuracy(skillId: "linux-proc", answers: 4, percent: 50), accuracy["linux-proc"])
    }

    func testStreakCountsBackFromTodayAndSurvivesUntilTheDayEnds() {
        let today = CalendarDay(string: "2026-11-10")!
        let practiced = Set(["2026-11-10", "2026-11-09", "2026-11-08", "2026-11-05"].compactMap(CalendarDay.init(string:)))
        XCTAssertEqual(3, Activity.streak(practiced: practiced, today: today))
        XCTAssertEqual(3, Activity.streak(practiced: practiced, today: today.adding(days: 1)))
        XCTAssertEqual(0, Activity.streak(practiced: practiced, today: today.adding(days: 2)))
        XCTAssertEqual(0, Activity.streak(practiced: [], today: today))
    }

    func testDailyTotalsComeFromTheAnswerLog() {
        let utc = TimeZone(identifier: "UTC")!
        let reviews = [
            ReviewState(questionId: "q1", skillId: "linux-proc", correct: true, hinted: false, xp: 10, at: 0),
            ReviewState(questionId: "q2", skillId: "linux-proc", correct: true, hinted: true, xp: 5, at: 1_000),
            ReviewState(questionId: "q3", skillId: "linux-proc", correct: false, hinted: false, xp: 0, at: day + 1),
        ]
        let days = Activity.days(reviews: reviews, zone: utc)
        XCTAssertEqual(Day(date: CalendarDay(string: "1970-01-01")!, xp: 15, answers: 2), days[CalendarDay(string: "1970-01-01")!])
        XCTAssertEqual(0, days[CalendarDay(string: "1970-01-02")!]?.xp)
    }

    func testASkillLessonAsksWhatIsDueThenNewQuestionsFromEasyToHard() {
        let questions = [
            question("a-hard", "linux-proc", difficulty: .hard),
            question("b-easy", "linux-proc", difficulty: .easy),
            question("c-medium", "linux-proc", difficulty: .medium),
            question("d-due", "linux-proc"),
            question("e-resting", "linux-proc"),
            question("other", "k8s-pods"),
        ]
        let attempts: [String: AttemptState] = [
            "d-due": attempt("d-due", "linux-proc", streak: 1, dueAt: 50),
            "e-resting": attempt("e-resting", "linux-proc", streak: 1, dueAt: 5_000),
        ]
        let lesson = LessonPlanner.plan(spec: .skillLesson(skillId: "linux-proc"), bank: bank(questions), attempts: attempts, now: 100, rng: RNG())
        XCTAssertEqual(["d-due", "b-easy", "c-medium", "a-hard"], lesson.map(\.id))
    }

    func testASkillLessonIsCappedAndAShortOneIsToppedUpWithPractice() {
        let many = (1 ... 9).map { question("q\($0)", "linux-proc") }
        XCTAssertEqual(
            LessonPlanner.skillSize,
            LessonPlanner.plan(spec: .skillLesson(skillId: "linux-proc"), bank: bank(many), attempts: [:], now: 0, rng: RNG()).count,
        )

        let resting = Dictionary(uniqueKeysWithValues: many.prefix(8).map {
            ($0.id, attempt($0.id, "linux-proc", streak: 1, dueAt: 5_000))
        })
        let topped = LessonPlanner.plan(spec: .skillLesson(skillId: "linux-proc"), bank: bank(many), attempts: resting, now: 100, rng: RNG())
        XCTAssertEqual(LessonPlanner.skillMin, topped.count)
        XCTAssertEqual("q9", topped.last?.id)
    }

    func testReviewServesWhatIsDueAndFallsBackToTheShakiestWhenNothingIs() {
        let questions = (1 ... 14).map {
            question(String(format: "q%02d", $0), $0 % 2 == 0 ? "linux-proc" : "k8s-pods")
        }
        var attempts: [String: AttemptState] = Dictionary(uniqueKeysWithValues: questions.prefix(12).map {
            ($0.id, attempt($0.id, $0.skillId, streak: 2, dueAt: 5_000))
        })
        attempts["q01"] = attempt("q01", "k8s-pods", streak: 1, dueAt: 10)
        attempts["q02"] = attempt("q02", "linux-proc", streak: 0, dueAt: 20)
        let due = LessonPlanner.plan(spec: .review, bank: bank(questions), attempts: attempts, now: 100, rng: RNG(1))
        XCTAssertEqual(Set(["q01", "q02"]), Set(due.map(\.id)))

        let nothingDue = LessonPlanner.plan(spec: .review, bank: bank(questions), attempts: attempts, now: 5, rng: RNG(1))
        XCTAssertEqual(LessonPlanner.mixedSize, nothingDue.count)
        XCTAssertTrue(nothingDue.allSatisfy { attempts[$0.id] != nil })
        XCTAssertTrue(Set(nothingDue.map(\.id)).isSuperset(of: ["q01", "q02"]))
    }

    func testMistakesServeOnlyQuestionsThatAreStillBeingLearned() {
        let questions = (1 ... 4).map { question("q\($0)", "linux-proc") }
        let attempts: [String: AttemptState] = [
            "q1": attempt("q1", "linux-proc", streak: 0, dueAt: 9_000),
            "q2": attempt("q2", "linux-proc", streak: 2, dueAt: 10),
        ]
        let lesson = LessonPlanner.plan(spec: .mistakes, bank: bank(questions), attempts: attempts, now: 100, rng: RNG())
        XCTAssertEqual(["q1"], lesson.map(\.id))
    }

    func testAUnitReviewSpreadsAcrossTheSkillsOfThatUnit() {
        let questions = (1 ... 12).map { question("pods-\($0)", "k8s-pods") }
            + (1 ... 12).map { question("net-\($0)", "k8s-net") }
            + (1 ... 12).map { question("linux-\($0)", "linux-proc") }
        let lesson = LessonPlanner.plan(spec: .unitReview(categoryId: "kubernetes"), bank: bank(questions), attempts: [:], now: 0, rng: RNG(7))
        XCTAssertEqual(LessonPlanner.mixedSize, lesson.count)
        XCTAssertEqual(lesson.count, Set(lesson.map(\.id)).count)
        XCTAssertTrue(lesson.allSatisfy { $0.skillId != "linux-proc" })
        XCTAssertTrue(lesson.filter { $0.skillId == "k8s-pods" }.count >= 2)
        XCTAssertTrue(lesson.filter { $0.skillId == "k8s-net" }.count >= 2)
    }

    func testALessonShufflesChoicesAndKeepsTrackOfTheAnswer() {
        let lesson = Lesson.start(questions: (1 ... 20).map { question("q\($0)", "linux-proc") }, rng: RNG(3))
        XCTAssertTrue(lesson.queue.allSatisfy { $0.choices[$0.answer] == "right" })
        XCTAssertTrue(Set(lesson.queue.map(\.answer)).count > 1)
    }

    func testAMissedQuestionComesBackUntilItIsRightAndOnlyTheFirstTryScores() {
        let random = RNG(5)
        var lesson = Lesson.start(questions: [question("q1", "linux-proc"), question("q2", "linux-proc")], rng: random)

        let wrong = (0 ... 3).first { $0 != lesson.current!.answer }!
        lesson.select(wrong)
        lesson.check()
        XCTAssertEqual(Outcome.wrong, lesson.verdict!.outcome)
        XCTAssertEqual(0, lesson.progress)
        lesson.advance(rng: random)

        lesson.select(lesson.current!.answer)
        lesson.check()
        XCTAssertEqual(Outcome.clean, lesson.verdict!.outcome)
        XCTAssertEqual(10, lesson.verdict!.xp)
        lesson.advance(rng: random)

        let again = lesson.current!
        XCTAssertTrue(again.retry)
        XCTAssertEqual("q1", again.question.id)
        lesson.select(again.answer)
        lesson.check()
        XCTAssertEqual(0, lesson.verdict!.xp)
        lesson.advance(rng: random)

        XCTAssertTrue(lesson.finished)
        XCTAssertEqual(1, lesson.progress)
        XCTAssertEqual(1, lesson.clean)
        XCTAssertEqual(10, lesson.xp)
        XCTAssertEqual(["q1"], lesson.missed.map(\.id))
        XCTAssertEqual(2, lesson.bestCombo)
    }

    func testAHintStrikesWrongChoicesOnlyAndHalvesTheReward() {
        let random = RNG(11)
        var lesson = Lesson.start(questions: [question("q1", "linux-proc")], rng: random)
        let answer = lesson.current!.answer
        let wrong = (0 ... 3).first { $0 != answer }!

        lesson.select(wrong)
        lesson.hint(rng: random)
        lesson.hint(rng: random)
        lesson.hint(rng: random)
        XCTAssertEqual(Lesson.maxHints, lesson.eliminated.count)
        XCTAssertFalse(lesson.eliminated.contains(answer))
        XCTAssertEqual(0, lesson.hintsLeft)
        if lesson.eliminated.contains(wrong) {
            XCTAssertNil(lesson.selected)
        }

        let selectedBefore = lesson.selected
        lesson.select(lesson.eliminated.first!)
        XCTAssertEqual(selectedBefore, lesson.selected)
        lesson.select(answer)
        lesson.check()
        XCTAssertEqual(Outcome.hinted, lesson.verdict!.outcome)
        XCTAssertEqual(5, lesson.verdict!.xp)
        XCTAssertEqual(0, lesson.clean)
    }

    func testNothingIsCheckedUntilAChoiceIsPicked() {
        var lesson = Lesson.start(questions: [question("q1", "linux-proc")], rng: RNG(2))
        lesson.check()
        XCTAssertNil(lesson.verdict)
        let queueBefore = lesson.queue.count
        lesson.advance(rng: RNG(2))
        XCTAssertEqual(queueBefore, lesson.queue.count)
    }
}
