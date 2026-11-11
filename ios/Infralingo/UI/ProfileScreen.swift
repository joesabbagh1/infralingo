import SwiftUI

struct ProfileScreen: View {
    let stats: TopStats
    let units: [UnitUi]
    let profile: ProfileUi
    let onGoal: (Int) -> Void
    let onExport: () -> Void
    let onImport: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Your progress")
                // Each pair shares the height of its taller tile.
                HStack(alignment: .top, spacing: 12) {
                    StatTile(value: "\(stats.streak)", label: "Day streak") {
                        FlameIcon(lit: stats.streak > 0).frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                    StatTile(value: grouped(stats.totalXp), label: "Total XP") {
                        BoltIcon().frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack(alignment: .top, spacing: 12) {
                    StatTile(value: profile.accuracy.map { "\($0)%" } ?? "–", label: "First-try accuracy") {
                        TargetIcon().frame(width: 28, height: 28)
                    }
                    .frame(maxWidth: .infinity)
                    StatTile(value: "\(profile.learned)/\(profile.questions)", label: "Questions learned") {
                        StarIcon(tint: palette.gold.face).frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                }

                SectionTitle(text: "This week")
                    .padding(.top, 12)
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            ForEach(Array(profile.week.enumerated()), id: \.offset) { index, day in
                                if index > 0 {
                                    Spacer(minLength: 0)
                                }
                                DayDot(day: day)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(palette.border)
                            .frame(height: 2)
                            .padding(.vertical, 14)
                        HStack {
                            Text("Daily goal")
                                .font(Type.bodyStrong)
                                .foregroundColor(palette.text)
                            Spacer()
                            Text("\(stats.todayXp) of \(stats.dailyGoal) XP today")
                                .font(Type.small)
                                .foregroundColor(palette.textSoft)
                        }
                        Meter(
                            progress: Double(stats.todayXp) / Double(max(stats.dailyGoal, 1)),
                            color: palette.blue.face,
                        )
                        .padding(.top, 8)
                        HStack(spacing: 8) {
                            ForEach(dailyGoals, id: \.self) { goal in
                                let picked = goal == stats.dailyGoal
                                ChunkyButton(
                                    face: picked ? palette.selectedTint : palette.background,
                                    edge: picked ? palette.selectedBorder : palette.border,
                                    action: { onGoal(goal) },
                                    border: 2,
                                    lip: 2,
                                    radius: 12,
                                    minHeight: 44,
                                    label: {
                                        Text("\(goal) XP")
                                            .font(Type.eyebrow)
                                            .foregroundColor(picked ? palette.selectedInk : palette.textSoft)
                                    },
                                )
                            }
                        }
                        .padding(.top, 14)
                    }
                }

                SectionTitle(text: "Units")
                    .padding(.top, 12)
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(units) { unit in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text(unit.title)
                                        .font(Type.bodyStrong)
                                        .foregroundColor(palette.text)
                                    Spacer()
                                    Text("\(unit.learned)/\(unit.total)")
                                        .font(Type.small)
                                        .foregroundColor(palette.textSoft)
                                }
                                Meter(
                                    progress: Double(unit.learned) / Double(max(unit.total, 1)),
                                    color: palette.unit(unit.index).face,
                                    height: 12,
                                    gloss: false,
                                )
                                .padding(.top, 6)
                            }
                        }
                    }
                }

                if !profile.strengths.isEmpty {
                    SectionTitle(text: "Strongest skills")
                        .padding(.top, 12)
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(profile.strengths, id: \.skillId) { skill in
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(skill.title)
                                            .font(Type.bodyStrong)
                                            .foregroundColor(palette.text)
                                        Text(skill.unitTitle)
                                            .font(Type.small)
                                            .foregroundColor(palette.textSoft)
                                    }
                                    Spacer()
                                    Text("\(skill.percent)%")
                                        .font(Type.heading)
                                        .foregroundColor(palette.text)
                                }
                            }
                        }
                    }
                }

                if !profile.mistakes.isEmpty {
                    SectionTitle(text: "Open mistakes")
                        .padding(.top, 12)
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(profile.mistakes, id: \.questionId) { miss in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(miss.skillTitle.uppercased())
                                        .font(Type.eyebrow)
                                        .kerning(Type.labelKerning)
                                        .foregroundColor(palette.wrongInk)
                                    Text(miss.prompt)
                                        .font(Type.body)
                                        .foregroundColor(palette.text)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                }

                SectionTitle(text: "Backup")
                    .padding(.top, 12)
                Text("Progress lives on this phone only. Export a file to keep a copy or move to another device.")
                    .font(Type.body)
                    .foregroundColor(palette.textSoft)
                HStack(spacing: 12) {
                    GhostButton("Export", action: onExport)
                    GhostButton("Import", action: onImport)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(palette.background)
    }

    private func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// A headline number: the value in ink, a short label under it, and a coloured mark beside them.
private struct StatTile<Icon: View>: View {
    let value: String
    let label: String
    @ViewBuilder var icon: () -> Icon

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            icon()
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Type.heading)
                    .foregroundColor(palette.text)
                Text(label)
                    .font(Type.small)
                    .foregroundColor(palette.textSoft)
                    .padding(.top, 1)
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .circular)
                .strokeBorder(palette.border, lineWidth: 2),
        )
    }
}

private struct DayDot: View {
    let day: DayUi

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Text(day.label)
                .font(Type.eyebrow)
                .foregroundColor(day.today ? palette.text : palette.textSoft)
                .frame(width: 34)
                .padding(.bottom, 6)
            ZStack {
                Circle()
                    .fill(day.practiced ? palette.orange.face : palette.idle.face)
                    .frame(width: 34, height: 34)
                if day.practiced {
                    CheckIcon(tint: palette.onTone)
                        .frame(width: 20, height: 20)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(day.today ? palette.text : .clear, lineWidth: 2)
            )
        }
    }
}

struct ReplaceProgressSheet: View {
    let onReplace: () -> Void
    let onCancel: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Text("Replace your progress?")
                .font(Type.title)
                .foregroundColor(palette.text)
            Text("Everything tracked on this phone is swapped for what is in the backup. This cannot be undone.")
                .font(Type.body)
                .foregroundColor(palette.textSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 20)
            DuoButton("Replace progress", action: onReplace, tone: palette.red)
            GhostButton("Cancel", action: onCancel, color: palette.textSoft)
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(palette.background)
    }
}
