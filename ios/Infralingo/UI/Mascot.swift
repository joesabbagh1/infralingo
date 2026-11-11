import SwiftUI

enum Mood {
    case happy
    case cheer
    case oops
}

private let ink = Color(hex: 0x3C3C3C)
private let blush = Color(hex: 0xFF9DB5)
private let lamp = Color(hex: 0xFFC800)
private let led = Color(hex: 0x1CB0F6)

/// The mascot: a little server with a face. Drawn on a 100 by 100 grid.
struct Mascot: View {
    var mood: Mood = .happy
    var skin: Tone?

    @Environment(\.palette) private var palette

    var body: some View {
        let tone = skin ?? palette.green
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            var context = context
            context.scaleBy(x: scale, y: scale)

            strokeLine(&context, tone.edge, 4, (50, 20), (50, 10))
            context.fill(Path(ellipseIn: CGRect(x: 44.5, y: 2.5, width: 11, height: 11)), with: .color(lamp))
            block(&context, tone.edge, x: 9, y: 40, w: 10, h: 20, r: 4)
            block(&context, tone.edge, x: 81, y: 40, w: 10, h: 20, r: 4)
            block(&context, tone.edge, x: 30, y: 84, w: 14, h: 9, r: 4)
            block(&context, tone.edge, x: 56, y: 84, w: 14, h: 9, r: 4)
            block(&context, tone.edge, x: 16, y: 23, w: 68, h: 66, r: 20)
            block(&context, tone.face, x: 16, y: 18, w: 68, h: 66, r: 20)
            block(&context, .white, x: 25, y: 28, w: 50, h: 38, r: 13)
            context.fill(Path(ellipseIn: CGRect(x: 28.1, y: 51.6, width: 6.8, height: 6.8)), with: .color(blush))
            context.fill(Path(ellipseIn: CGRect(x: 65.1, y: 51.6, width: 6.8, height: 6.8)), with: .color(blush))
            drawFace(mood, &context)
            context.fill(Path(ellipseIn: CGRect(x: 37.4, y: 72.9, width: 5.2, height: 5.2)), with: .color(lamp))
            context.fill(Path(ellipseIn: CGRect(x: 47.4, y: 72.9, width: 5.2, height: 5.2)), with: .color(.white.opacity(0.9)))
            context.fill(Path(ellipseIn: CGRect(x: 57.4, y: 72.9, width: 5.2, height: 5.2)), with: .color(led))
        }
    }

    private func block(_ context: inout GraphicsContext, _ color: Color, x: Float, y: Float, w: Float, h: Float, r: Float) {
        let shape = Path(
            roundedRect: CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)),
            cornerSize: CGSize(width: CGFloat(r), height: CGFloat(r)),
        )
        context.fill(shape, with: .color(color))
    }

    /// A stroked arc, as Compose's drawArc draws it: 0° is 3 o'clock and the sweep runs clockwise.
    private func curve(_ context: inout GraphicsContext, startAngle: Float, x: Float, y: Float, w: Float, h: Float) {
        let path = Path { path in
            path.addArc(
                center: CGPoint(x: CGFloat(x + w / 2), y: CGFloat(y + h / 2)),
                radius: CGFloat(w / 2),
                startAngle: .degrees(Double(startAngle)),
                endAngle: .degrees(Double(startAngle + 140)),
                clockwise: false,
            )
        }
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
    }

    private func drawFace(_ mood: Mood, _ context: inout GraphicsContext) {
        func eye(_ x: CGFloat, _ y: CGFloat) {
            context.fill(Path(ellipseIn: CGRect(x: x - 5.6, y: y - 5.6, width: 11.2, height: 11.2)), with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(x: x + 1.8 - 1.9, y: y - 1.9 - 1.9, width: 3.8, height: 3.8)), with: .color(.white))
        }
        switch mood {
        case .happy:
            eye(39, 44.5)
            eye(61, 44.5)
            curve(&context, startAngle: 20, x: 43, y: 46, w: 14, h: 12)
        case .cheer:
            curve(&context, startAngle: 200, x: 33.5, y: 41, w: 11, h: 10)
            curve(&context, startAngle: 200, x: 55.5, y: 41, w: 11, h: 10)
            // The open mouth: the bottom half of a circle, filled.
            let mouth = Path { path in
                path.addArc(
                    center: CGPoint(x: 50, y: 53.5),
                    radius: 7.5,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false,
                )
                path.closeSubpath()
            }
            context.fill(mouth, with: .color(ink))
        case .oops:
            eye(39, 46)
            eye(61, 46)
            curve(&context, startAngle: 200, x: 43.5, y: 55, w: 13, h: 10)
        }
    }
}
