import SwiftUI

private let nodeLip: CGFloat = 8

// How far each step of the path swings from the centre line, in pt. Odd units mirror it.
private let wave: [CGFloat] = [0, 44, 70, 44, 0, -44, -70, -44]

private func sway(_ unit: Int, _ step: Int) -> CGFloat {
    wave[step % wave.count] * (unit % 2 == 0 ? 1 : -1)
}

struct LearnScreen: View {
    let stats: TopStats
    let units: [UnitUi]
    let onStart: (LessonSpec) -> Void

    @Environment(\.palette) private var palette
    @State private var open: String?
    @State private var showUnits = false
    @State private var scrolledToCurrent = false
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            StatsBar(stats: stats)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(units) { unit in
                            Section {
                                nodeRows(unit)
                            } header: {
                                UnitBanner(unit: unit) { showUnits = true }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .onAppear {
                    scrollProxy = proxy
                    guard !scrolledToCurrent else { return }
                    scrolledToCurrent = true
                    // Land on the suggested node so the pinned banner does not sit on it.
                    for unit in units {
                        if let node = unit.nodes.first(where: { $0.current }) {
                            proxy.scrollTo(node.id, anchor: .top)
                            break
                        }
                    }
                }
            }
        }
        .background(palette.background)
        .sheet(isPresented: $showUnits) {
            UnitList(units: units) { unit in
                showUnits = false
                open = nil
                if let node = unit.nodes.first {
                    withAnimation {
                        scrollProxy?.scrollTo(node.id, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nodeRows(_ unit: UnitUi) -> some View {
        ForEach(unit.nodes) { node in
            let step = unit.nodes.firstIndex(of: node) ?? 0
            let tone = node.state == .mastered ? palette.gold : palette.unit(unit.index)
            let offset = sway(unit.index, step)
            PathRow(
                offset: offset,
                expanded: open == node.skillId,
                companion: step == 2
                    ? .mascot(unit.index % 2 == 0 ? .happy : .cheer, palette.unit(unit.index))
                    : nil,
                card: {
                    NodeCard(
                        tone: tone,
                        caret: offset,
                        title: node.title,
                        detail: detail(node),
                        action: action(node),
                        onStart: {
                            open = nil
                            onStart(.skillLesson(skillId: node.skillId))
                        },
                    )
                },
                node: {
                    SkillNode(node: node, tone: tone) {
                        open = open == node.skillId ? nil : node.skillId
                    }
                },
            )
        }
        unitReviewRow(unit)
    }

    @ViewBuilder
    private func unitReviewRow(_ unit: UnitUi) -> some View {
        let key = "review:\(unit.id)"
        let tone: Tone = {
            if unit.complete { return palette.gold }
            if unit.started { return palette.unit(unit.index) }
            return palette.idle
        }()
        let offset = sway(unit.index, unit.nodes.count)
        PathRow(
            offset: offset,
            expanded: open == key,
            companion: nil,
            card: {
                NodeCard(
                    tone: unit.started ? tone : palette.unit(unit.index),
                    caret: offset,
                    title: "Unit review",
                    detail: "A mix of questions from all of \(unit.title).",
                    action: "Start",
                    onStart: {
                        open = nil
                        onStart(.unitReview(categoryId: unit.id))
                    },
                )
            },
            node: {
                VStack(spacing: 0) {
                    NodeButton(
                        face: tone.face,
                        edge: tone.edge,
                    ) {
                        TrophyIcon(tint: unit.started ? palette.onTone : palette.idleText)
                            .frame(width: 38, height: 38)
                    }
                    NodeLabel(text: "Unit review")
                }
                .padding(.bottom, 20)
            },
        )
    }

    private func detail(_ node: NodeUi) -> String {
        switch node.state {
        case .notStarted, .upNext:
            return "\(node.total) questions"
        case .inProgress:
            return "\(node.learned) of \(node.total) learned" + (node.due > 0 ? " · \(node.due) due" : "")
        case .complete:
            if node.due > 0 {
                return "All \(node.total) learned · \(node.due) due for review"
            }
            return "All \(node.total) learned. Reviews keep it fresh."
        case .mastered:
            if node.due > 0 {
                return "Mastered · \(node.due) due for review"
            }
            return "Mastered. Recalled across weeks of reviews."
        }
    }

    private func action(_ node: NodeUi) -> String {
        switch node.state {
        case .notStarted: return "Jump here"
        case .upNext: return "Start"
        case .inProgress: return "Continue"
        case .complete, .mastered: return node.due > 0 ? "Review" : "Practice"
        }
    }
}

private enum Companion {
    case mascot(Mood, Tone)
}

/// One step of the path: a node pushed off the centre line, and the card that opens under it.
private struct PathRow<Node: View, Card: View>: View {
    let offset: CGFloat
    let expanded: Bool
    var companion: Companion?
    @ViewBuilder var card: () -> Card
    @ViewBuilder var node: () -> Node

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if case .mascot(let mood, let tone)? = companion {
                    Mascot(mood: mood, skin: tone)
                        .frame(width: 88, height: 88)
                        .frame(maxWidth: .infinity, alignment: offset > 0 ? .leading : .trailing)
                        .padding(.horizontal, 36)
                }
                node().offset(x: offset)
            }
            .frame(maxWidth: .infinity)
            if expanded {
                VStack(spacing: 0) { card() }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 6)
        .animation(.easeOut(duration: 0.18), value: expanded)
    }
}

private struct StatsBar: View {
    let stats: TopStats

    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            IconLabel(
                color: stats.practicedToday ? palette.text : palette.textFaint,
                text: "\(stats.streak)",
            ) {
                FlameIcon(lit: stats.practicedToday).frame(width: 28, height: 28)
            }
            Spacer()
            IconLabel(color: palette.text, text: "\(stats.totalXp) XP") {
                BoltIcon().frame(width: 26, height: 26)
            }
            Spacer()
            IconLabel(color: palette.text, text: "\(stats.todayXp)/\(stats.dailyGoal)") {
                GoalRing(xp: stats.todayXp, goal: stats.dailyGoal)
                    .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(palette.background)
    }
}

/// Today's XP against the daily goal.
struct GoalRing: View {
    let xp: Int
    let goal: Int

    @Environment(\.palette) private var palette

    var body: some View {
        let reached = xp >= goal
        ZStack {
            Canvas { context, size in
                let stroke = min(size.width, size.height) * 0.2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = (min(size.width, size.height) - stroke) / 2
                if reached {
                    context.fill(
                        Path(ellipseIn: CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                        with: .color(palette.blue.face),
                    )
                } else {
                    var track = Path()
                    track.addEllipse(in: CGRect(x: stroke / 2, y: stroke / 2, width: size.width - stroke, height: size.height - stroke))
                    context.stroke(track, with: .color(palette.blue.face.opacity(0.22)), style: StrokeStyle(lineWidth: stroke))
                    var fill = Path()
                    fill.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * Double(xp) / Double(max(goal, 1))),
                        clockwise: false,
                    )
                    context.stroke(fill, with: .color(palette.blue.face), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                }
            }
            if reached {
                CheckIcon(tint: palette.onTone)
                    .padding(5)
            }
        }
    }
}

private struct UnitBanner: View {
    let unit: UnitUi
    let onClick: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let tone = palette.unit(unit.index)
        HStack {
            ChunkyButton(
                face: tone.face,
                edge: tone.edge,
                action: onClick,
                alignment: .leading,
                label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("UNIT \(unit.index + 1)")
                                .labelStyle(font: Type.eyebrow, color: palette.onTone)
                            Text(unit.title)
                                .font(Type.heading)
                                .foregroundColor(palette.onTone)
                                .padding(.top, 2)
                            HStack(spacing: 10) {
                                Meter(
                                    progress: Double(unit.learned) / Double(max(unit.total, 1)),
                                    color: palette.onTone,
                                    track: palette.onTone.opacity(0.3),
                                    height: 8,
                                    gloss: false,
                                )
                                Text("\(unit.learned)/\(unit.total)")
                                    .font(Type.eyebrow)
                                    .foregroundColor(palette.onTone)
                            }
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MenuIcon(tint: palette.onTone)
                            .frame(width: 26, height: 26)
                            .padding(.leading, 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                },
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(palette.background)
    }
}

private struct SkillNode: View {
    let node: NodeUi
    let tone: Tone
    let onClick: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let idle = node.state == .notStarted
        let face = idle ? palette.idle : tone
        VStack(spacing: 0) {
            if node.current {
                StartBubble(
                    text: node.state == .inProgress ? "Continue" : "Start",
                    color: palette.dark ? tone.face : tone.edge,
                )
            }
            NodeButton(
                face: face.face,
                edge: face.edge,
                ring: node.state == .inProgress
                    ? Double(node.learned) / Double(max(node.total, 1))
                    : (node.current ? 0 : nil),
                ringColor: tone.face,
                badge: node.due > 0 ? node.due : nil,
                onClick: onClick,
            ) {
                let tint = idle ? palette.idleText : palette.onTone
                switch node.state {
                case .mastered:
                    CrownIcon(tint: tint).frame(width: 38, height: 38)
                case .complete:
                    CheckIcon(tint: tint).frame(width: 36, height: 36)
                default:
                    StarIcon(tint: tint).frame(width: 38, height: 38)
                }
            }
            NodeLabel(text: node.title)
        }
    }
}

private struct NodeLabel: View {
    let text: String

    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Type.small)
            .foregroundColor(palette.textSoft)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 150)
    }
}

private struct NodeButton<Content: View>: View {
    var face: Color
    var edge: Color
    var ring: Double?
    var ringColor: Color = .clear
    var badge: Int?
    var onClick: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if let ring {
                RingCanvas(ring: ring, ringColor: ringColor, trackColor: palette.border)
                    .frame(width: 92, height: 92)
            }
            Button(action: onClick) {
                content()
                    .padding(.bottom, nodeLip)
            }
            .buttonStyle(OvalStyle(face: face, edge: edge))
            if let badge {
                ZStack {
                    Circle().fill(palette.background).frame(width: 26, height: 26)
                    Circle().fill(palette.orange.face).frame(width: 22, height: 22)
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(Type.eyebrow)
                        .foregroundColor(palette.onTone)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 6)
                .padding(.trailing, 4)
            }
        }
        .frame(width: 92, height: 92)
    }
}

/// The oval slab a node sits on: face over edge, lip at the bottom, face sinking on press.
private struct OvalStyle: ButtonStyle {
    var face: Color
    var edge: Color

    func makeBody(configuration: Configuration) -> some View {
        let sink: CGFloat = configuration.isPressed ? nodeLip : 0
        ZStack(alignment: .center) {
            ZStack(alignment: .top) {
                Ellipse()
                    .fill(edge)
                    .frame(width: 66, height: 62 - nodeLip)
                    .offset(y: nodeLip)
                Ellipse()
                    .fill(face)
                    .frame(width: 66, height: 62 - nodeLip)
                    .offset(y: sink)
            }
            .frame(width: 66, height: 62)
            configuration.label
                .offset(y: sink)
        }
        .frame(width: 66, height: 62)
        .contentShape(Ellipse())
        .animation(.easeOut(duration: 0.06), value: sink)
    }
}

private struct RingCanvas: View {
    let ring: Double
    let ringColor: Color
    let trackColor: Color

    var body: some View {
        Canvas { context, size in
            let stroke: CGFloat = 7
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = (min(size.width, size.height) - stroke) / 2
            var track = Path()
            track.addEllipse(in: CGRect(x: stroke / 2, y: stroke / 2, width: size.width - stroke, height: size.height - stroke))
            context.stroke(track, with: .color(trackColor), style: StrokeStyle(lineWidth: stroke))
            if ring > 0 {
                var fill = Path()
                fill.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * ring),
                    clockwise: false,
                )
                context.stroke(fill, with: .color(ringColor), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
    }
}

/// The bobbing callout over the suggested node.
private struct StartBubble: View {
    let text: String
    let color: Color

    @Environment(\.palette) private var palette
    @State private var bob = false

    var body: some View {
        Text(text.uppercased())
            .labelStyle(color: color)
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.top, 9)
            .padding(.bottom, 17)
            .background(BubbleShape(border: palette.border, fill: palette.background))
            .offset(y: bob ? -6 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    bob = true
                }
            }
    }
}

private struct BubbleShape: View {
    let border: Color
    let fill: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let line: CGFloat = 2
            let tail: CGFloat = 8
            let bodyRect = CGRect(x: 0, y: 0, width: w, height: h - tail)
            context.fill(
                Path(roundedRect: bodyRect, cornerSize: CGSize(width: 12, height: 12)),
                with: .color(border),
            )
            context.fill(
                Path(roundedRect: bodyRect.insetBy(dx: line, dy: line), cornerSize: CGSize(width: 10, height: 10)),
                with: .color(fill),
            )
            let middle = w / 2
            var tip = Path()
            tip.move(to: CGPoint(x: middle - tail, y: bodyRect.maxY - line))
            tip.addLine(to: CGPoint(x: middle, y: bodyRect.maxY + tail - line))
            tip.addLine(to: CGPoint(x: middle + tail, y: bodyRect.maxY - line))
            tip.closeSubpath()
            context.fill(tip, with: .color(fill))
            context.stroke(tip, with: .color(border), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }
    }
}

/// What opens under a tapped node: what it is, where it stands, and the button that starts it.
private struct NodeCard: View {
    let tone: Tone
    let caret: CGFloat
    let title: String
    let detail: String
    let action: String
    let onStart: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            CaretCanvas(color: tone.face, caret: caret)
                .frame(height: 10)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Type.heading)
                    .foregroundColor(palette.onTone)
                Text(detail)
                    .font(Type.body)
                    .foregroundColor(palette.onTone)
                    .padding(.top, 2)
                ChunkyButton(
                    face: palette.dark ? palette.background : .white,
                    edge: .black.opacity(0.2),
                    action: onStart,
                    minHeight: 50,
                    label: {
                        Text(action)
                            .labelStyle(color: palette.dark ? tone.face : tone.edge)
                    },
                )
                .padding(.top, 14)
            }
            .padding(16)
            .background(tone.face, in: RoundedRectangle(cornerRadius: 16, style: .circular))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}

private struct CaretCanvas: View {
    let color: Color
    let caret: CGFloat

    var body: some View {
        Canvas { context, size in
            let middle = size.width / 2 + caret
            let half: CGFloat = 11
            var path = Path()
            path.move(to: CGPoint(x: middle - half, y: size.height))
            path.addLine(to: CGPoint(x: middle, y: 0))
            path.addLine(to: CGPoint(x: middle + half, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
    }
}

private struct UnitList: View {
    let units: [UnitUi]
    let onPick: (UnitUi) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Units")
                    .padding(.bottom, 4)
                ForEach(units) { unit in
                    let tone = palette.unit(unit.index)
                    ChunkyButton(
                        face: palette.background,
                        edge: palette.border,
                        action: { onPick(unit) },
                        border: 2,
                        lip: 2,
                        alignment: .leading,
                        label: {
                            HStack(spacing: 0) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .circular)
                                        .fill(tone.face)
                                        .frame(width: 44, height: 44)
                                    Text("\(unit.index + 1)")
                                        .font(Type.heading)
                                        .foregroundColor(palette.onTone)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(unit.title)
                                        .font(Type.bodyStrong)
                                        .foregroundColor(palette.text)
                                    HStack(spacing: 10) {
                                        Meter(
                                            progress: Double(unit.learned) / Double(max(unit.total, 1)),
                                            color: tone.face,
                                            height: 10,
                                            gloss: false,
                                        )
                                        Text("\(unit.learned)/\(unit.total)")
                                            .font(Type.eyebrow)
                                            .foregroundColor(palette.textSoft)
                                            .frame(width: 52, alignment: .trailing)
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.leading, 12)
                            }
                            .padding(12)
                        },
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(palette.background)
    }
}
