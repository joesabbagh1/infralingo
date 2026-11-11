// Renders the launcher icon: the mascot centred on the Infralingo green.
// Run: swift tools/make_icon.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make_icon.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let output = arguments[1]

let size = 1_024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha,
    )
}

let green = rgb(0x58CC02)
let white = rgb(0xFFFFFF)
let ink = rgb(0x3C3C3C)
let gold = rgb(0xFFC800)
let blue = rgb(0x1CB0F6)
let blush = rgb(0xFF9DB5)

// The Android icon centres the 108-grid art at 66% of the tile.
let side = CGFloat(size) * 0.62
let left = (CGFloat(size) - side) / 2
let top = (CGFloat(size) - side) / 2
let unit = side / 100

// Green tile, full bleed.
context.setFillColor(green)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Everything below is drawn in the 100-grid, origin at the tile's top-left, y running down:
// move to the tile's bottom-left corner (CG y runs up), flip, then shift the grid down 100 units.
context.saveGState()
context.translateBy(x: left, y: top)
context.scaleBy(x: unit, y: -unit)
context.translateBy(x: 0, y: -100)

func block(_ color: CGColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
    let rect = CGRect(x: x, y: y, width: w, height: h)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: r,
        cornerHeight: r,
        transform: nil,
    )
    context.setFillColor(color)
    context.addPath(path)
    context.fillPath()
}

func circle(_ color: CGColor, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
}

// Antenna, ears, feet, then the body stack.
context.setStrokeColor(white)
context.setLineWidth(4)
context.setLineCap(.round)
context.move(to: CGPoint(x: 50, y: 20))
context.addLine(to: CGPoint(x: 50, y: 10))
context.strokePath()
circle(gold, 50, 8, 5.5)

block(ink, 9, 40, 10, 20, 4)
block(ink, 81, 40, 10, 20, 4)
block(ink, 30, 84, 14, 9, 4)
block(ink, 56, 84, 14, 9, 4)
block(ink, 16, 23, 68, 66, 20)
block(white, 16, 18, 68, 66, 20)
block(white, 25, 28, 50, 38, 13)
circle(blush, 31.5, 55, 3.4)
circle(blush, 68.5, 55, 3.4)

// Face: eyes and smile.
circle(ink, 39, 44.5, 5.6)
circle(white, 40.8, 42.6, 1.9)
circle(ink, 61, 44.5, 5.6)
circle(white, 62.8, 42.6, 1.9)

// Smile: a quad curve approximating the mascot's arc, well below the eyes.
context.setStrokeColor(ink)
context.setLineWidth(3.2)
context.setLineCap(.round)
let smile = CGMutablePath()
smile.move(to: CGPoint(x: 43.4, y: 53.5))
smile.addQuadCurve(to: CGPoint(x: 56.6, y: 53.5), control: CGPoint(x: 50, y: 59.5))
context.addPath(smile)
context.strokePath()

// Status LEDs.
circle(gold, 40, 75.5, 2.6)
circle(white, 50, 75.5, 2.6)
circle(blue, 60, 75.5, 2.6)

context.restoreGState()

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: output) as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil,
)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("Failed to write \(output)\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(output)")
