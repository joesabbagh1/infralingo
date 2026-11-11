import SwiftUI

// Every icon is drawn on a 24 by 24 grid and scaled to whatever size the caller gives it.

private let flameColor = Color(hex: 0xFF9600)
private let sunColor = Color(hex: 0xFFC800)
private let skyColor = Color(hex: 0x1CB0F6)
private let cherryColor = Color(hex: 0xFF4B4B)
private let ashColor = Color(hex: 0xAFAFAF)

typealias Pt = (Float, Float)

private func makePath(_ build: (inout Path) -> Void) -> Path {
    var path = Path()
    build(&path)
    return path
}

private func polygon(_ points: Pt...) -> Path {
    makePath { path in
        guard let first = points.first else { return }
        path.move(to: CGPoint(x: CGFloat(first.0), y: CGFloat(first.1)))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: CGFloat(point.0), y: CGFloat(point.1)))
        }
        path.closeSubpath()
    }
}

private func cubic(_ from: Pt, _ c1: Pt, _ c2: Pt, _ to: Pt, into path: inout Path) {
    path.addCurve(
        to: CGPoint(x: CGFloat(to.0), y: CGFloat(to.1)),
        control1: CGPoint(x: CGFloat(c1.0), y: CGFloat(c1.1)),
        control2: CGPoint(x: CGFloat(c2.0), y: CGFloat(c2.1)),
    )
}

/// Fills a shape and strokes it in the same colour, which rounds off its corners.
private func soft(_ context: inout GraphicsContext, _ shape: Path, _ color: Color, round: CGFloat = 1.4) {
    context.fill(shape, with: .color(color))
    context.stroke(shape, with: .color(color), style: StrokeStyle(lineWidth: round, lineCap: .round, lineJoin: .round))
}

/// A round-capped polyline, shared with the mascot's drawing code.
func strokeLine(_ context: inout GraphicsContext, _ color: Color, _ width: CGFloat, _ points: Pt...) {
    let stroke = makePath { path in
        guard let first = points.first else { return }
        path.move(to: CGPoint(x: CGFloat(first.0), y: CGFloat(first.1)))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: CGFloat(point.0), y: CGFloat(point.1)))
        }
    }
    context.stroke(stroke, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
}

private func pill(_ context: inout GraphicsContext, _ color: Color, _ x: Float, _ y: Float, _ w: Float, _ h: Float, _ r: Float) {
    let shape = Path(roundedRect: CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)), cornerSize: CGSize(width: CGFloat(r), height: CGFloat(r)))
    context.fill(shape, with: .color(color))
}

/// The shared canvas: scales the 24-grid drawing to fill the view.
private func drawIn(_ context: inout GraphicsContext, _ size: CGSize, _ draw: (inout GraphicsContext) -> Void) {
    let scale = min(size.width, size.height) / 24
    context.scaleBy(x: scale, y: scale)
    draw(&context)
}

private func canvas(_ draw: @escaping (inout GraphicsContext) -> Void) -> some View {
    Canvas { context, size in
        drawIn(&context, size, draw)
    }
}

// MARK: - Shapes

private let flameOuter = makePath { path in
    path.move(to: CGPoint(x: 12, y: 1.8))
    cubic((12, 1.8), (12.6, 5.4), (16.8, 7.6), (18.6, 11.6), into: &path)
    cubic((18.6, 11.6), (20.6, 16.2), (17.4, 22), (12, 22), into: &path)
    cubic((12, 22), (6.8, 22), (3.6, 17.6), (5, 12.8), into: &path)
    cubic((5, 12.8), (5.6, 10.6), (7.2, 9.2), (7.6, 7.2), into: &path)
    cubic((7.6, 7.2), (8.8, 8.2), (9.4, 9.2), (9.8, 10.4), into: &path)
    cubic((9.8, 10.4), (10.6, 7.6), (11.8, 5), (12, 1.8), into: &path)
    path.closeSubpath()
}

private let flameInner = makePath { path in
    path.move(to: CGPoint(x: 12, y: 12.2))
    cubic((12, 12.2), (13.2, 13.8), (15.2, 15.2), (15.2, 17.4), into: &path)
    cubic((15.2, 17.4), (15.2, 19.4), (13.8, 20.6), (12, 20.6), into: &path)
    cubic((12, 20.6), (10.2, 20.6), (8.8, 19.4), (8.8, 17.4), into: &path)
    cubic((8.8, 17.4), (8.8, 15.2), (10.8, 13.8), (12, 12.2), into: &path)
    path.closeSubpath()
}

private let bolt = polygon(
    (14, 2), (5.2, 13.4), (10.8, 13.4), (9.6, 22), (18.8, 10.2), (13, 10.2),
)

private let starShape = makePath { path in
    for point in 0 ..< 10 {
        let radius: Double = point % 2 == 0 ? 9.6 : 4.6
        let angle = -Double.pi / 2 + Double(point) * .pi / 5
        let x = 12.0 + radius * cos(angle)
        let y = 12.8 + radius * sin(angle)
        if point == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
}

private let crown = polygon(
    (3.6, 8.4), (8, 12.4), (12, 5.4), (16, 12.4), (20.4, 8.4), (18.6, 18.6), (5.4, 18.6),
)

private let cup = makePath { path in
    path.move(to: CGPoint(x: 7, y: 4))
    path.addLine(to: CGPoint(x: 17, y: 4))
    path.addLine(to: CGPoint(x: 17, y: 10))
    cubic((17, 10), (17, 12.8), (14.8, 15), (12, 15), into: &path)
    cubic((12, 15), (9.2, 15), (7, 12.8), (7, 10), into: &path)
    path.closeSubpath()
}

private let house = polygon(
    (12, 3.2), (21, 11.2), (18.6, 11.2), (18.6, 20.2), (14, 20.2), (14, 14.6),
    (10, 14.6), (10, 20.2), (5.4, 20.2), (5.4, 11.2), (3, 11.2),
)

private let shoulders = makePath { path in
    path.move(to: CGPoint(x: 4.4, y: 20.6))
    cubic((4.4, 20.6), (4.4, 16.6), (7.8, 14.4), (12, 14.4), into: &path)
    cubic((12, 14.4), (16.2, 14.4), (19.6, 16.6), (19.6, 20.6), into: &path)
    path.closeSubpath()
}

private let sparkle = makePath { path in
    path.move(to: CGPoint(x: 12, y: 2.6))
    cubic((12, 2.6), (12.7, 8), (16, 11.3), (21.4, 12), into: &path)
    cubic((21.4, 12), (16, 12.7), (12.7, 16), (12, 21.4), into: &path)
    cubic((12, 21.4), (11.3, 16), (8, 12.7), (2.6, 12), into: &path)
    cubic((2.6, 12), (8, 11.3), (11.3, 8), (12, 2.6), into: &path)
    path.closeSubpath()
}

// MARK: - Icons

struct FlameIcon: View {
    var lit: Bool = true

    var body: some View {
        canvas { context in
            context.fill(flameOuter, with: .color(lit ? flameColor : ashColor))
            context.fill(flameInner, with: .color(lit ? sunColor : Color.white.opacity(0.55)))
        }
    }
}

struct BoltIcon: View {
    var tint: Color = sunColor

    var body: some View {
        canvas { context in
            soft(&context, bolt, tint)
        }
    }
}

struct StarIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            soft(&context, starShape, tint, round: 2)
        }
    }
}

struct CrownIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            soft(&context, crown, tint, round: 2)
        }
    }
}

struct CheckIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            strokeLine(&context, tint, 3.6, (5.4, 12.6), (10, 17.2), (18.6, 7.4))
        }
    }
}

struct CrossIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            strokeLine(&context, tint, 3.2, (6.2, 6.2), (17.8, 17.8))
            strokeLine(&context, tint, 3.2, (17.8, 6.2), (6.2, 17.8))
        }
    }
}

struct TrophyIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            soft(&context, cup, tint, round: 1.2)
            strokeLine(&context, tint, 2, (7, 6), (4.4, 6), (4.4, 8), (5.4, 10.2), (7.6, 11.2))
            strokeLine(&context, tint, 2, (17, 6), (19.6, 6), (19.6, 8), (18.6, 10.2), (16.4, 11.2))
            pill(&context, tint, 11, 14.6, 2, 4, 0)
            pill(&context, tint, 7.6, 18.2, 8.8, 2.8, 1.2)
        }
    }
}

struct DumbbellIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            pill(&context, tint, 6, 10.8, 12, 2.4, 1)
            pill(&context, tint, 4.8, 6, 3.6, 12, 1.5)
            pill(&context, tint, 15.6, 6, 3.6, 12, 1.5)
            pill(&context, tint, 2, 8.6, 2.6, 6.8, 1.2)
            pill(&context, tint, 19.4, 8.6, 2.6, 6.8, 1.2)
        }
    }
}

struct BulbIcon: View {
    var lit: Bool = true

    var body: some View {
        canvas { context in
            let glass = lit ? sunColor : ashColor
            context.fill(Path(ellipseIn: CGRect(x: 5.4, y: 2.8, width: 13.2, height: 13.2)), with: .color(glass))
            pill(&context, glass, 9.2, 13.6, 5.6, 3.4, 0.6)
            if lit {
                context.fill(Path(ellipseIn: CGRect(x: 8.3, y: 5.7, width: 3, height: 3)), with: .color(.white.opacity(0.75)))
            }
            pill(&context, ashColor, 9.2, 17.8, 5.6, 1.8, 0.9)
            pill(&context, ashColor, 10.4, 20.2, 3.2, 1.6, 0.8)
        }
    }
}

struct TargetIcon: View {
    var body: some View {
        canvas { context in
            context.fill(Path(ellipseIn: CGRect(x: 2, y: 2, width: 20, height: 20)), with: .color(cherryColor))
            context.fill(Path(ellipseIn: CGRect(x: 5.2, y: 5.2, width: 13.6, height: 13.6)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: 8.4, y: 8.4, width: 7.2, height: 7.2)), with: .color(cherryColor))
        }
    }
}

struct ClockIcon: View {
    var body: some View {
        canvas { context in
            context.fill(Path(ellipseIn: CGRect(x: 2, y: 2, width: 20, height: 20)), with: .color(skyColor))
            strokeLine(&context, .white, 2.4, (12, 6.8), (12, 12), (15.6, 14.2))
        }
    }
}

struct HomeIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            soft(&context, house, tint, round: 1.6)
        }
    }
}

struct PersonIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            context.fill(Path(ellipseIn: CGRect(x: 7.6, y: 3.6, width: 8.8, height: 8.8)), with: .color(tint))
            soft(&context, shoulders, tint, round: 1.2)
        }
    }
}

struct SparkleIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            soft(&context, sparkle, tint, round: 0.8)
        }
    }
}

struct ChevronIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            strokeLine(&context, tint, 2.8, (9, 5.6), (15.4, 12), (9, 18.4))
        }
    }
}

struct MenuIcon: View {
    var tint: Color

    var body: some View {
        canvas { context in
            strokeLine(&context, tint, 2.6, (5, 7), (19, 7))
            strokeLine(&context, tint, 2.6, (5, 12), (19, 12))
            strokeLine(&context, tint, 2.6, (5, 17), (19, 17))
        }
    }
}
