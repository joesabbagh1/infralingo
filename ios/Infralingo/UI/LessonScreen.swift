import SwiftUI
import UIKit

struct LessonScreen: View {
    let ui: LessonUi
    let onSelect: (Int) -> Void
    let onHint: () -> Void
    let onCheck: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var leaving = false

    var body: some View {
        if let summary = ui.summary {
            LessonComplete(summary: summary, onDone: onClose)
        } else {
            lessonBody
                .sheet(isPresented: $leaving, onDismiss: { leaving = false }) {
                    LeaveSheet(
                        onStay: { leaving = false },
                        onLeave: {
                            leaving = false
                            onClose()
                        },
                    )
                }
        }
    }

    private var lessonBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    leaving = true
                } label: {
                    CrossIcon(tint: palette.textFaint)
                        .frame(width: 26, height: 26)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave lesson")
                Meter(progress: ui.progress, color: palette.green.face, track: palette.border)
                    .padding(.trailing, 20)
            }
            .padding(.leading, 8)
            .padding(.top, 8)

            ComboLine(combo: ui.combo)

            ZStack {
                questionBody
                    .id(ui.question.key)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity),
                    ))
            }
            .animation(.easeOut(duration: 0.22), value: ui.question.key)
            .frame(maxHeight: .infinity)

            ZStack(alignment: .bottom) {
                if ui.feedback == nil {
                    ActionBar(hintsLeft: ui.hintsLeft, canCheck: ui.canCheck, onHint: onHint, onCheck: onCheck)
                        .transition(.opacity)
                } else if let feedback = ui.feedback {
                    FeedbackPanel(feedback: feedback, onNext: onNext)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: ui.feedback == nil)
        }
        .background(palette.background)
        .onChange(of: ui.feedback?.correct) { _, correct in
            guard let correct else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(correct ? .success : .error)
        }
    }

    private var questionBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                QuestionTagLine(tag: ui.question.tag)
                Text("\(ui.question.unitTitle) · \(ui.question.skillTitle)")
                    .font(Type.small)
                    .foregroundColor(palette.textSoft)
                    .padding(.top, 4)
                Text(ui.question.prompt)
                    .font(Type.prompt)
                    .foregroundColor(palette.text)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                VStack(spacing: 12) {
                    ForEach(ui.question.choices) { choice in
                        ChoiceCard(choice: choice) {
                            onSelect(choice.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ComboLine: View {
    let combo: Int

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if combo >= 3 {
                HStack(spacing: 4) {
                    FlameIcon()
                        .frame(width: 18, height: 18)
                    Text("\(combo) IN A ROW")
                        .labelStyle(font: Type.eyebrow, color: palette.orange.edge)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: combo)
    }
}

private struct QuestionTagLine: View {
    let tag: QuestionTag

    @Environment(\.palette) private var palette

    var body: some View {
        let (label, color): (String, Color) = {
            switch tag {
            case .new: return ("New question", palette.selectedInk)
            case .review: return ("Review", palette.correctInk)
            case .mistake: return ("Previous mistake", palette.orange.edge)
            case .retry: return ("One more try", palette.orange.edge)
            }
        }()
        HStack(spacing: 6) {
            SparkleIcon(tint: color)
                .frame(width: 16, height: 16)
            Text(label.uppercased())
                .font(Type.eyebrow)
                .kerning(Type.labelKerning)
                .foregroundColor(color)
        }
    }
}

private struct ChoiceCard: View {
    let choice: ChoiceUi
    let onClick: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let face: Color = {
            switch choice.state {
            case .selected: return palette.selectedTint
            case .correct: return palette.correctTint
            case .wrong: return palette.wrongTint
            default: return palette.background
            }
        }()
        let edge: Color = {
            switch choice.state {
            case .selected: return palette.selectedBorder
            case .correct: return palette.correctBorder
            case .wrong: return palette.wrongBorder
            default: return palette.border
            }
        }()
        let ink: Color = {
            switch choice.state {
            case .idle: return palette.text
            case .selected: return palette.selectedInk
            case .correct: return palette.correctBody
            case .wrong: return palette.wrongBody
            case .struck: return palette.textFaint
            case .rest: return palette.textSoft
            }
        }()
        ChunkyButton(
            face: face,
            edge: edge,
            action: onClick,
            enabled: choice.state == .idle || choice.state == .selected,
            border: 2,
            lip: 2,
            alignment: .leading,
            label: {
                HStack(spacing: 0) {
                    Text(choice.text)
                        .font(Type.body)
                        .foregroundColor(ink)
                        .strikethrough(choice.state == .struck)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    switch choice.state {
                    case .correct:
                        CheckIcon(tint: palette.correctInk)
                            .frame(width: 22, height: 22)
                            .padding(.leading, 10)
                    case .wrong:
                        CrossIcon(tint: palette.wrongInk)
                            .frame(width: 22, height: 22)
                            .padding(.leading, 10)
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            },
        )
        .opacity(choice.state == .struck ? 0.6 : 1)
        .animation(.easeOut(duration: 0.12), value: choice.state)
    }
}

private struct ActionBar: View {
    let hintsLeft: Int
    let canCheck: Bool
    let onHint: () -> Void
    let onCheck: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 2)
            HStack(spacing: 12) {
                ChunkyButton(
                    face: palette.background,
                    edge: palette.border,
                    action: onHint,
                    enabled: hintsLeft > 0,
                    border: 2,
                    lip: 2,
                    expandWidth: false,
                    minHeight: 52,
                    label: {
                        HStack(spacing: 0) {
                            BulbIcon(lit: hintsLeft > 0)
                                .frame(width: 26, height: 26)
                            Text("Hint")
                                .labelStyle(color: hintsLeft > 0 ? palette.textSoft : palette.idleText)
                                .padding(.leading, 6)
                            Text("\(hintsLeft)")
                                .font(Type.eyebrow)
                                .foregroundColor(hintsLeft > 0 ? palette.text : palette.idleText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(palette.raised, in: Circle())
                                .padding(.leading, 8)
                        }
                        .padding(.horizontal, 14)
                    },
                )
                DuoButton("Check", action: onCheck, enabled: canCheck)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(palette.background)
    }
}

private struct FeedbackPanel: View {
    let feedback: FeedbackUi
    let onNext: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let tint = feedback.correct ? palette.correctTint : palette.wrongTint
        let ink = feedback.correct ? palette.correctInk : palette.wrongInk
        let bodyColor = feedback.correct ? palette.correctBody : palette.wrongBody
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().fill(ink).frame(width: 32, height: 32)
                    if feedback.correct {
                        CheckIcon(tint: tint).frame(width: 20, height: 20)
                    } else {
                        CrossIcon(tint: tint).frame(width: 18, height: 18)
                    }
                }
                Text(feedback.title)
                    .font(Type.title)
                    .foregroundColor(ink)
                    .padding(.leading, 10)
                Spacer()
                if feedback.xp > 0 {
                    Text("+\(feedback.xp) XP")
                        .labelStyle(color: ink)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !feedback.correct {
                        Text("Correct answer")
                            .font(Type.bodyStrong)
                            .foregroundColor(ink)
                        Text(feedback.answer)
                            .font(Type.body)
                            .foregroundColor(bodyColor)
                            .padding(.bottom, 10)
                    }
                    Text(feedback.explanation)
                        .font(Type.body)
                        .foregroundColor(bodyColor)
                    if let note = feedback.note {
                        Text(note)
                            .font(Type.small)
                            .foregroundColor(ink)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 10)
            .frame(maxHeight: 230)

            HStack(spacing: 4) {
                PanelLink(text: "Ask AI", color: ink) {
                    SparkleIcon(tint: ink).frame(width: 18, height: 18)
                } action: {
                    let activity = UIActivityViewController(activityItems: [feedback.askAi], applicationActivities: nil)
                    UIApplication.shared.connectedScenes
                        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                        .first?.present(activity, animated: true)
                }
            }
            .padding(.top, 6)

            DuoButton(
                feedback.correct ? "Continue" : "Got it",
                action: onNext,
                tone: feedback.correct ? palette.green : palette.red,
            )
            .padding(.top, 6)
        }
        .padding(16)
        .background(tint)
    }
}

private struct PanelLink<Icon: View>: View {
    let text: String
    let color: Color
    @ViewBuilder var icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon()
                Text(text.uppercased())
                    .font(Type.eyebrow)
                    .kerning(Type.labelKerning)
                    .foregroundColor(color)
            }
            .padding(.trailing, 14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LeaveSheet: View {
    let onStay: () -> Void
    let onLeave: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Mascot(mood: .oops)
                .frame(width: 96, height: 96)
            Text("Leave the lesson?")
                .font(Type.title)
                .foregroundColor(palette.text)
                .padding(.top, 8)
            Text("Your answers so far are saved. The questions you have not reached will still be here.")
                .font(Type.body)
                .foregroundColor(palette.textSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 20)
            DuoButton("Keep learning", action: onStay, tone: palette.blue)
            GhostButton("End lesson", action: onLeave, color: palette.wrongInk)
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(palette.background)
    }
}

private struct LessonComplete: View {
    let summary: SummaryUi
    let onDone: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Confetti(colors: [palette.green, palette.blue, palette.gold, palette.red, palette.unit(1)].map(\.face))
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Mascot(mood: .cheer)
                            .frame(width: 150, height: 150)
                        Text(summary.title)
                            .font(Type.display)
                            .foregroundColor(palette.dark ? palette.gold.face : palette.gold.edge)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                        Text(blurb)
                            .font(Type.body)
                            .foregroundColor(palette.textSoft)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                        HStack(spacing: 10) {
                            ResultTile(label: "Total XP", tone: palette.gold) {
                                BoltIcon().frame(width: 22, height: 22)
                            } value: {
                                CountingNumber(target: summary.xp)
                            }
                            .frame(maxWidth: .infinity)
                            ResultTile(label: "Accuracy", tone: palette.green) {
                                TargetIcon().frame(width: 20, height: 20)
                            } value: {
                                HStack(spacing: 0) {
                                    CountingNumber(target: summary.accuracy)
                                    Text("%")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            ResultTile(label: "Time", tone: palette.blue) {
                                ClockIcon().frame(width: 20, height: 20)
                            } value: {
                                Text(timeText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if summary.streakExtended || summary.goalReached || summary.bestCombo >= 3 {
                            Panel {
                                VStack(alignment: .leading, spacing: 10) {
                                    if summary.streakExtended {
                                        ResultLine(text: "\(summary.streak) day streak") {
                                            FlameIcon().frame(width: 24, height: 24)
                                        }
                                    }
                                    if summary.goalReached {
                                        ResultLine(text: "Daily goal reached: \(summary.todayXp) of \(summary.dailyGoal) XP") {
                                            GoalRing(xp: summary.todayXp, goal: summary.dailyGoal)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    if summary.bestCombo >= 3 {
                                        ResultLine(text: "\(summary.bestCombo) right in a row") {
                                            StarIcon(tint: palette.gold.face).frame(width: 24, height: 24)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity)
                        }
                        if !summary.revisit.isEmpty {
                            Panel {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("WORTH ANOTHER LOOK")
                                        .labelStyle(font: Type.eyebrow, color: palette.textSoft)
                                    Text(summary.revisit.joined(separator: " · "))
                                        .font(Type.body)
                                        .foregroundColor(palette.text)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                DuoButton("Continue", action: onDone)
                    .padding(.top, 16)
            }
            .padding(20)
        }
        .background(palette.background)
    }

    private var blurb: String {
        if summary.accuracy == 100 {
            return "Flawless. Every answer right the first time."
        }
        if summary.accuracy >= 80 {
            return "Strong work. Anything shaky comes back tomorrow."
        }
        return "The shaky ones come back tomorrow."
    }

    private var timeText: String {
        String(format: "%d:%02d", summary.seconds / 60, summary.seconds % 60)
    }
}

/// Counts a number up from zero, the way the Android summary does.
private struct CountingNumber: View {
    let target: Int

    @State private var current: Double = 0

    var body: some View {
        Text("\(Int(current))")
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    current = Double(target)
                }
            }
    }
}

private struct ResultTile<Icon: View, Value: View>: View {
    let label: String
    let tone: Tone
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var value: () -> Value

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Text(label.uppercased())
                .font(Type.eyebrow)
                .foregroundColor(palette.onTone)
                .padding(.vertical, 5)
            HStack(spacing: 6) {
                icon()
                value()
                    .font(Type.heading)
                    .foregroundColor(palette.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 14, style: .circular))
        }
        .background(tone.face, in: RoundedRectangle(cornerRadius: 16, style: .circular))
        .padding(2)
    }
}

private struct ResultLine<Icon: View>: View {
    let text: String
    @ViewBuilder var icon: () -> Icon

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            icon()
            Text(text)
                .font(Type.bodyStrong)
                .foregroundColor(palette.text)
        }
    }
}

private struct Piece {
    let x: Double
    let delay: Double
    let fall: Double
    let drift: Double
    let width: Double
    let height: Double
    let turns: Double
    let color: Int
}

/// One burst of paper falling from the top of the screen.
private struct Confetti: View {
    let colors: [Color]

    @State private var started: Date?

    private let pieces: [Piece] = (0 ..< 80).map { _ in
        Piece(
            x: Double.random(in: 0 ... 1),
            delay: Double.random(in: 0 ... 1) * 0.3,
            fall: 0.8 + Double.random(in: 0 ... 1) * 0.6,
            drift: (Double.random(in: 0 ... 1) - 0.5) * 0.3,
            width: 8 + Double.random(in: 0 ... 1) * 8,
            height: 12 + Double.random(in: 0 ... 1) * 12,
            turns: 1 + Double.random(in: 0 ... 1) * 3,
            color: Int.random(in: 0 ..< 5),
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard let started else { return }
                let elapsed = timeline.date.timeIntervalSince(started) / 2.8
                if elapsed >= 1 { return }
                for piece in pieces {
                    let along = min(max((elapsed - piece.delay) / (1 - piece.delay), 0), 1) * piece.fall
                    if along <= 0 { continue }
                    let centre = CGPoint(
                        x: (piece.x + piece.drift * along) * size.width,
                        y: along * size.height * 1.15 - piece.height,
                    )
                    var pieceContext = context
                    pieceContext.translateBy(x: centre.x, y: centre.y)
                    pieceContext.rotate(by: .degrees(piece.turns * along * 360))
                    let rect = CGRect(
                        x: -piece.width / 2,
                        y: -piece.height / 2,
                        width: piece.width,
                        height: piece.height,
                    )
                    pieceContext.fill(Path(rect), with: .color(colors[piece.color % colors.count].opacity(min(max(1.6 - along * 1.4, 0), 1))))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { started = Date() }
    }
}
