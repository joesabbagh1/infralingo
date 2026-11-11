import SwiftUI

/// The raised slab everything pressable is made of: a face sitting on an edge that shows as a lip along
/// the bottom. Pressing sinks the face onto the lip. With a border the edge also outlines the face.
///
/// `expandWidth` matches the Kotlin call sites: everything stretches to the offered width except the
/// hint button in the lesson's action bar, which hugs its content.
struct ChunkyButton<Label: View>: View {
    var face: Color
    var edge: Color
    var action: () -> Void
    var enabled: Bool = true
    var border: CGFloat = 0
    var lip: CGFloat = 4
    var radius: CGFloat = 16
    var alignment: Alignment = .center
    var expandWidth: Bool = true
    /// Smallest height for the pressable area (content plus lip), like Compose's heightIn(min).
    var minHeight: CGFloat? = nil
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: { if enabled { action() } }, label: label)
            .buttonStyle(ChunkyStyle(
                face: face,
                edge: edge,
                border: border,
                lip: lip,
                radius: radius,
                enabled: enabled,
                alignment: alignment,
                expandWidth: expandWidth,
                minHeight: minHeight,
            ))
            .disabled(!enabled)
    }
}

private struct ChunkyStyle: ButtonStyle {
    var face: Color
    var edge: Color
    var border: CGFloat
    var lip: CGFloat
    var radius: CGFloat
    var enabled: Bool
    var alignment: Alignment
    var expandWidth: Bool
    var minHeight: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        let sink: CGFloat = configuration.isPressed && enabled ? lip : 0
        configuration.label
            .frame(minHeight: minHeight.map { $0 - lip }, alignment: alignment)
            .padding(.bottom, lip)
            .frame(maxWidth: expandWidth ? .infinity : nil, alignment: alignment)
            .background(ChunkySlab(face: face, edge: edge, border: border, lip: lip, radius: radius))
            .offset(y: sink)
            .animation(.easeOut(duration: 0.06), value: sink)
    }
}

/// The two rounded slabs behind a chunky button.
struct ChunkySlab: View {
    var face: Color
    var edge: Color
    var border: CGFloat
    var lip: CGFloat
    var radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h), cornerSize: CGSize(width: radius, height: radius))
            }
            .fill(edge)
            Path { path in
                path.addRoundedRect(
                    in: CGRect(x: border, y: border, width: w - 2 * border, height: h - lip - 2 * border),
                    cornerSize: CGSize(width: max(radius - border, 0), height: max(radius - border, 0)),
                )
            }
            .fill(face)
        }
    }
}

/// The green (or any tone) primary button.
struct DuoButton: View {
    var text: String
    var action: () -> Void
    var tone: Tone?
    var enabled: Bool = true

    init(_ text: String, action: @escaping () -> Void, tone: Tone? = nil, enabled: Bool = true) {
        self.text = text
        self.action = action
        self.tone = tone
        self.enabled = enabled
    }

    @Environment(\.palette) private var palette

    var body: some View {
        let t = tone ?? palette.green
        ChunkyButton(
            face: enabled ? t.face : palette.idle.face,
            edge: enabled ? t.edge : palette.idle.face,
            action: action,
            enabled: enabled,
            minHeight: 52,
            label: {
                Text(text)
                    .labelStyle(color: enabled ? palette.onTone : palette.idleText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            },
        )
    }
}

/// The quieter button: page-coloured face, grey outline, coloured label.
struct GhostButton: View {
    var text: String
    var action: () -> Void
    var color: Color?
    var enabled: Bool = true

    init(_ text: String, action: @escaping () -> Void, color: Color? = nil, enabled: Bool = true) {
        self.text = text
        self.action = action
        self.color = color
        self.enabled = enabled
    }

    @Environment(\.palette) private var palette

    var body: some View {
        ChunkyButton(
            face: palette.background,
            edge: palette.border,
            action: action,
            enabled: enabled,
            border: 2,
            lip: 2,
            minHeight: 52,
            label: {
                Text(text)
                    .labelStyle(color: enabled ? (color ?? palette.selectedInk) : palette.idleText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            },
        )
    }
}

/// A flat outlined card for content that is read, not pressed.
struct Panel<Content: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .circular)
                .strokeBorder(palette.border, lineWidth: 2),
        )
    }
}

/// A progress track. The unfilled part is a lighter step of the fill unless `track` says otherwise.
struct Meter: View {
    var progress: Double
    var color: Color
    var track: Color?
    var height: CGFloat = 16
    var gloss: Bool = true

    var body: some View {
        let value = min(max(progress, 0), 1)
        ZStack(alignment: .leading) {
            MeterFill(progress: 1, height: height)
                .fill(track ?? color.opacity(0.22))
            if value > 0 {
                MeterFill(progress: value, height: height)
                    .fill(color)
                if gloss {
                    MeterGloss(progress: value, height: height)
                        .fill(.white.opacity(0.28))
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 1.0), value: value)
    }
}

private struct MeterFill: Shape {
    var progress: CGFloat
    var height: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = max(rect.width * progress, height)
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: width, height: height),
            cornerSize: CGSize(width: height / 2, height: height / 2),
        )
        return path
    }
}

/// The light stripe along the top of a long fill.
private struct MeterGloss: Shape {
    var progress: CGFloat
    var height: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let width = max(rect.width * progress, height)
        guard width > height * 1.5 else { return Path() }
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: height * 0.5, y: height * 0.25, width: width - height, height: height * 0.25),
            cornerSize: CGSize(width: height * 0.25, height: height * 0.25),
        )
        return path
    }
}

struct SectionTitle: View {
    var text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Type.title)
            .foregroundColor(palette.text)
    }
}

struct IconLabel<Icon: View>: View {
    var color: Color
    var text: String
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 6) {
            icon()
            Text(text)
                .font(Type.heading)
                .foregroundColor(color)
        }
    }
}
