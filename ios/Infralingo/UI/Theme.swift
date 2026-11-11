import SwiftUI

/// A chunky colour: the face of a button and the darker lip underneath it.
struct Tone: Equatable {
    let face: Color
    let edge: Color

    init(hex: UInt32, edgeHex: UInt32) {
        face = Color(hex: hex)
        edge = Color(hex: edgeHex)
    }
}

struct Palette: Equatable {
    let dark: Bool
    let background: Color
    let raised: Color
    let border: Color
    let text: Color
    let textSoft: Color
    let textFaint: Color
    /// Text and icons sitting on a coloured face.
    let onTone: Color
    let green: Tone
    let blue: Tone
    let red: Tone
    let gold: Tone
    let orange: Tone
    /// Nodes that have not been started and buttons that cannot be pressed.
    let idle: Tone
    let idleText: Color
    let correctTint: Color
    let correctBorder: Color
    let correctInk: Color
    let correctBody: Color
    let wrongTint: Color
    let wrongBorder: Color
    let wrongInk: Color
    let wrongBody: Color
    let selectedTint: Color
    let selectedBorder: Color
    let selectedInk: Color
    /// One per unit, in path order, reused when the path is longer.
    let units: [Tone]

    func unit(_ index: Int) -> Tone {
        let i = index % units.count
        return units[index >= 0 ? i : i + units.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}

let lightPalette = Palette(
    dark: false,
    background: Color(hex: 0xFFFFFF),
    raised: Color(hex: 0xF7F7F7),
    border: Color(hex: 0xE5E5E5),
    text: Color(hex: 0x3C3C3C),
    textSoft: Color(hex: 0x777777),
    textFaint: Color(hex: 0xAFAFAF),
    onTone: Color(hex: 0xFFFFFF),
    green: Tone(hex: 0x58CC02, edgeHex: 0x58A700),
    blue: Tone(hex: 0x1CB0F6, edgeHex: 0x1899D6),
    red: Tone(hex: 0xFF4B4B, edgeHex: 0xEA2B2B),
    gold: Tone(hex: 0xFFC800, edgeHex: 0xE5A600),
    orange: Tone(hex: 0xFF9600, edgeHex: 0xCD7900),
    idle: Tone(hex: 0xE5E5E5, edgeHex: 0xB7B7B7),
    idleText: Color(hex: 0xAFAFAF),
    correctTint: Color(hex: 0xD7FFB8),
    correctBorder: Color(hex: 0xA5ED6E),
    correctInk: Color(hex: 0x58A700),
    correctBody: Color(hex: 0x3F7D00),
    wrongTint: Color(hex: 0xFFDFE0),
    wrongBorder: Color(hex: 0xFFB2B2),
    wrongInk: Color(hex: 0xEA2B2B),
    wrongBody: Color(hex: 0xB82525),
    selectedTint: Color(hex: 0xDDF4FF),
    selectedBorder: Color(hex: 0x84D8FF),
    selectedInk: Color(hex: 0x1899D6),
    units: [
        Tone(hex: 0x58CC02, edgeHex: 0x46A302),
        Tone(hex: 0xCE82FF, edgeHex: 0xA568CC),
        Tone(hex: 0x1CB0F6, edgeHex: 0x1899D6),
        Tone(hex: 0xFF9600, edgeHex: 0xCD7900),
        Tone(hex: 0xFF86D0, edgeHex: 0xD968AE),
        Tone(hex: 0x00CD9C, edgeHex: 0x00A47D),
    ],
)

let darkPalette = Palette(
    dark: true,
    background: Color(hex: 0x131F24),
    raised: Color(hex: 0x202F36),
    border: Color(hex: 0x37464F),
    text: Color(hex: 0xF1F7FB),
    textSoft: Color(hex: 0xA3B3BC),
    textFaint: Color(hex: 0x6A7E89),
    onTone: Color(hex: 0x131F24),
    green: Tone(hex: 0x93D333, edgeHex: 0x79B933),
    blue: Tone(hex: 0x49C0F8, edgeHex: 0x1899D6),
    red: Tone(hex: 0xEE5555, edgeHex: 0xC94444),
    gold: Tone(hex: 0xFFC800, edgeHex: 0xCC9F00),
    orange: Tone(hex: 0xFFAB33, edgeHex: 0xD98A1F),
    idle: Tone(hex: 0x37464F, edgeHex: 0x2A3840),
    idleText: Color(hex: 0x6A7E89),
    correctTint: Color(hex: 0x202F36),
    correctBorder: Color(hex: 0x5F8428),
    correctInk: Color(hex: 0x93D333),
    correctBody: Color(hex: 0xD2EFB4),
    wrongTint: Color(hex: 0x202F36),
    wrongBorder: Color(hex: 0x8C3A3A),
    wrongInk: Color(hex: 0xEE5555),
    wrongBody: Color(hex: 0xF5C6C6),
    selectedTint: Color(hex: 0x202F36),
    selectedBorder: Color(hex: 0x3F85A7),
    selectedInk: Color(hex: 0x49C0F8),
    units: [
        Tone(hex: 0x93D333, edgeHex: 0x79B933),
        Tone(hex: 0xCE82FF, edgeHex: 0xA568CC),
        Tone(hex: 0x49C0F8, edgeHex: 0x1899D6),
        Tone(hex: 0xFFAB33, edgeHex: 0xD98A1F),
        Tone(hex: 0xFF86D0, edgeHex: 0xD968AE),
        Tone(hex: 0x2BE0B4, edgeHex: 0x00B88C),
    ],
)

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = lightPalette
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Typography set in Nunito. The file is variable, so each style picks its own weight.
enum Type {
    static let display = Font.custom("Nunito", size: 30).weight(.black)
    static let title = Font.custom("Nunito", size: 24).weight(.heavy)
    static let prompt = Font.custom("Nunito", size: 21).weight(.heavy)
    static let heading = Font.custom("Nunito", size: 18).weight(.heavy)
    static let body = Font.custom("Nunito", size: 16).weight(.semibold)
    static let bodyStrong = Font.custom("Nunito", size: 16).weight(.heavy)
    static let small = Font.custom("Nunito", size: 14).weight(.bold)

    /// Buttons and eyebrow labels. Set in capitals by the caller.
    static let label = Font.custom("Nunito", size: 15).weight(.heavy)
    static let eyebrow = Font.custom("Nunito", size: 13).weight(.heavy)

    /// Letter spacing that goes with `label`/`eyebrow` (0.8sp in the Android port).
    static let labelKerning: CGFloat = 0.8
}

struct InfralingoTheme<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        let palette = scheme == .dark ? darkPalette : lightPalette
        content()
            .environment(\.palette, palette)
            .tint(palette.green.face)
    }
}

extension Text {
    /// Uppercase label text with the letter spacing the buttons use.
    func labelStyle(font: Font = Type.label, color: Color) -> some View {
        self.textCase(.uppercase)
            .font(font)
            .kerning(Type.labelKerning)
            .foregroundColor(color)
    }
}
