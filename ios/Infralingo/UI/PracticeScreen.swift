import SwiftUI

struct PracticeScreen: View {
    let practice: PracticeUi
    let onStart: (LessonSpec) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle(text: "Practice")
                    Text("Short sessions that stop what you learned from fading.")
                        .font(Type.body)
                        .foregroundColor(palette.textSoft)
                        .padding(.top, 2)
                }
                ReviewCard(practice: practice, onStart: { onStart(.review) })
                ActionRow(
                    title: "Mistakes",
                    detail: {
                        switch practice.mistakes {
                        case 0: return "Nothing to fix right now."
                        case 1: return "1 question you missed or needed a hint on."
                        default: return "\(practice.mistakes) questions you missed or needed a hint on."
                        }
                    }(),
                    enabled: practice.mistakes > 0,
                    onClick: { onStart(.mistakes) },
                    badge: {
                        Badge(color: practice.mistakes > 0 ? palette.red.face : palette.idle.face) {
                            CrossIcon(tint: practice.mistakes > 0 ? palette.onTone : palette.idleText)
                                .frame(width: 24, height: 24)
                        }
                    },
                )

                SectionTitle(text: "Weak spots")
                    .padding(.top, 10)
                if practice.weakSpots.isEmpty {
                    Text("Skills where your recent answers slip below 70% show up here, ready to drill.")
                        .font(Type.body)
                        .foregroundColor(palette.textSoft)
                }
                ForEach(Array(practice.weakSpots.enumerated()), id: \.element.skillId) { _, spot in
                    let tone = palette.unit(spot.unitIndex)
                    ActionRow(
                        title: spot.title,
                        detail: "\(spot.unitTitle) · \(spot.percent)% right lately",
                        enabled: true,
                        onClick: { onStart(.skillLesson(skillId: spot.skillId)) },
                        meter: Meter(
                            progress: Double(spot.percent) / 100,
                            color: tone.face,
                            height: 10,
                            gloss: false,
                        ),
                        badge: {
                            Badge(color: tone.face) {
                                DumbbellIcon(tint: palette.onTone)
                                    .frame(width: 26, height: 26)
                            }
                        },
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(palette.background)
    }
}

private struct ReviewCard: View {
    let practice: PracticeUi
    let onStart: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let tone = palette.blue
        let title: String = {
            if practice.due == 1 { return "1 question is due" }
            if practice.due > 1 { return "\(practice.due) questions are due" }
            if practice.seen > 0 { return "All caught up" }
            return "Nothing to review yet"
        }()
        let detail: String = {
            if practice.due > 0 {
                return "Answering them today is what moves them into long-term memory."
            }
            if practice.seen > 0 {
                return "The next review is \(practice.nextDueIn.map { until($0) } ?? "a while away")."
            }
            return "Finish a lesson and its questions come back here on a schedule."
        }()
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SPACED REVIEW")
                        .labelStyle(font: Type.eyebrow, color: palette.onTone)
                    Text(title)
                        .font(Type.title)
                        .foregroundColor(palette.onTone)
                        .padding(.top, 2)
                    Text(detail)
                        .font(Type.body)
                        .foregroundColor(palette.onTone)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Mascot(mood: practice.due > 0 ? .happy : .cheer, skin: palette.gold)
                    .frame(width: 84, height: 84)
                    .padding(.leading, 8)
            }
            if practice.seen > 0 {
                ChunkyButton(
                    face: palette.dark ? palette.background : .white,
                    edge: .black.opacity(0.2),
                    action: onStart,
                    minHeight: 50,
                    label: {
                        Text(practice.due > 0 ? "Review now" : "Practice anyway")
                            .labelStyle(color: palette.dark ? tone.face : tone.edge)
                    },
                )
                .padding(.top, 14)
            }
        }
        .padding(16)
        .background(tone.face, in: RoundedRectangle(cornerRadius: 16, style: .circular))
    }
}

private func until(_ millis: Int64) -> String {
    let minutes = millis / 60_000
    if minutes < 60 { return "in \(max(minutes, 1)) min" }
    if minutes < 48 * 60 { return "in \(minutes / 60) h" }
    return "in \(minutes / (24 * 60)) days"
}

private struct Badge<Content: View>: View {
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(color)
                .frame(width: 48, height: 48)
            content()
        }
    }
}

/// A pressable row: a badge, two lines of text, and a chevron when there is somewhere to go.
struct ActionRow<BadgeContent: View>: View {
    let title: String
    let detail: String
    let enabled: Bool
    let onClick: () -> Void
    var meter: Meter?
    @ViewBuilder var badge: () -> BadgeContent

    @Environment(\.palette) private var palette

    var body: some View {
        ChunkyButton(
            face: palette.background,
            edge: palette.border,
            action: onClick,
            enabled: enabled,
            border: 2,
            lip: 2,
            alignment: .leading,
            label: {
                HStack(spacing: 0) {
                    badge()
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(Type.bodyStrong)
                            .foregroundColor(enabled ? palette.text : palette.textSoft)
                        Text(detail)
                            .font(Type.small)
                            .foregroundColor(palette.textSoft)
                            .padding(.top, 1)
                        if let meter {
                            meter
                                .padding(.top, 6)
                        }
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if enabled {
                        ChevronIcon(tint: palette.textFaint)
                            .frame(width: 22, height: 22)
                            .padding(.leading, 8)
                    }
                }
                .padding(12)
            },
        )
    }
}
