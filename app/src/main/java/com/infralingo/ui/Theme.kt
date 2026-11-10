package com.infralingo.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.infralingo.R

/** A chunky colour: the face of a button and the darker lip underneath it. */
@Immutable
data class Tone(val face: Color, val edge: Color)

@Immutable
data class Palette(
    val dark: Boolean,
    val background: Color,
    val raised: Color,
    val border: Color,
    val text: Color,
    val textSoft: Color,
    val textFaint: Color,
    /** Text and icons sitting on a coloured face. */
    val onTone: Color,
    val green: Tone,
    val blue: Tone,
    val red: Tone,
    val gold: Tone,
    val orange: Tone,
    /** Nodes that have not been started and buttons that cannot be pressed. */
    val idle: Tone,
    val idleText: Color,
    val correctTint: Color,
    val correctBorder: Color,
    val correctInk: Color,
    val correctBody: Color,
    val wrongTint: Color,
    val wrongBorder: Color,
    val wrongInk: Color,
    val wrongBody: Color,
    val selectedTint: Color,
    val selectedBorder: Color,
    val selectedInk: Color,
    /** One per unit, in path order, reused when the path is longer. */
    val units: List<Tone>,
) {
    fun unit(index: Int): Tone = units[index.mod(units.size)]
}

private val LightPalette = Palette(
    dark = false,
    background = Color(0xFFFFFFFF),
    raised = Color(0xFFF7F7F7),
    border = Color(0xFFE5E5E5),
    text = Color(0xFF3C3C3C),
    textSoft = Color(0xFF777777),
    textFaint = Color(0xFFAFAFAF),
    onTone = Color(0xFFFFFFFF),
    green = Tone(Color(0xFF58CC02), Color(0xFF58A700)),
    blue = Tone(Color(0xFF1CB0F6), Color(0xFF1899D6)),
    red = Tone(Color(0xFFFF4B4B), Color(0xFFEA2B2B)),
    gold = Tone(Color(0xFFFFC800), Color(0xFFE5A600)),
    orange = Tone(Color(0xFFFF9600), Color(0xFFCD7900)),
    idle = Tone(Color(0xFFE5E5E5), Color(0xFFB7B7B7)),
    idleText = Color(0xFFAFAFAF),
    correctTint = Color(0xFFD7FFB8),
    correctBorder = Color(0xFFA5ED6E),
    correctInk = Color(0xFF58A700),
    correctBody = Color(0xFF3F7D00),
    wrongTint = Color(0xFFFFDFE0),
    wrongBorder = Color(0xFFFFB2B2),
    wrongInk = Color(0xFFEA2B2B),
    wrongBody = Color(0xFFB82525),
    selectedTint = Color(0xFFDDF4FF),
    selectedBorder = Color(0xFF84D8FF),
    selectedInk = Color(0xFF1899D6),
    units = listOf(
        Tone(Color(0xFF58CC02), Color(0xFF46A302)),
        Tone(Color(0xFFCE82FF), Color(0xFFA568CC)),
        Tone(Color(0xFF1CB0F6), Color(0xFF1899D6)),
        Tone(Color(0xFFFF9600), Color(0xFFCD7900)),
        Tone(Color(0xFFFF86D0), Color(0xFFD968AE)),
        Tone(Color(0xFF00CD9C), Color(0xFF00A47D)),
    ),
)

private val DarkPalette = Palette(
    dark = true,
    background = Color(0xFF131F24),
    raised = Color(0xFF202F36),
    border = Color(0xFF37464F),
    text = Color(0xFFF1F7FB),
    textSoft = Color(0xFFA3B3BC),
    textFaint = Color(0xFF6A7E89),
    onTone = Color(0xFF131F24),
    green = Tone(Color(0xFF93D333), Color(0xFF79B933)),
    blue = Tone(Color(0xFF49C0F8), Color(0xFF1899D6)),
    red = Tone(Color(0xFFEE5555), Color(0xFFC94444)),
    gold = Tone(Color(0xFFFFC800), Color(0xFFCC9F00)),
    orange = Tone(Color(0xFFFFAB33), Color(0xFFD98A1F)),
    idle = Tone(Color(0xFF37464F), Color(0xFF2A3840)),
    idleText = Color(0xFF6A7E89),
    correctTint = Color(0xFF202F36),
    correctBorder = Color(0xFF5F8428),
    correctInk = Color(0xFF93D333),
    correctBody = Color(0xFFD2EFB4),
    wrongTint = Color(0xFF202F36),
    wrongBorder = Color(0xFF8C3A3A),
    wrongInk = Color(0xFFEE5555),
    wrongBody = Color(0xFFF5C6C6),
    selectedTint = Color(0xFF202F36),
    selectedBorder = Color(0xFF3F85A7),
    selectedInk = Color(0xFF49C0F8),
    units = listOf(
        Tone(Color(0xFF93D333), Color(0xFF79B933)),
        Tone(Color(0xFFCE82FF), Color(0xFFA568CC)),
        Tone(Color(0xFF49C0F8), Color(0xFF1899D6)),
        Tone(Color(0xFFFFAB33), Color(0xFFD98A1F)),
        Tone(Color(0xFFFF86D0), Color(0xFFD968AE)),
        Tone(Color(0xFF2BE0B4), Color(0xFF00B88C)),
    ),
)

val LocalPalette = staticCompositionLocalOf { LightPalette }

// One variable font file. Each weight has to name its own axis value or it renders at the file's default.
@OptIn(ExperimentalTextApi::class)
private val Nunito = FontFamily(
    listOf(500, 600, 700, 800, 900).map { weight ->
        Font(
            resId = R.font.nunito,
            weight = FontWeight(weight),
            variationSettings = FontVariation.Settings(FontVariation.weight(weight)),
        )
    },
)

object Type {
    val display = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W900, fontSize = 30.sp, lineHeight = 36.sp)
    val title = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W800, fontSize = 24.sp, lineHeight = 30.sp)
    val prompt = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W800, fontSize = 21.sp, lineHeight = 28.sp)
    val heading = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W800, fontSize = 18.sp, lineHeight = 24.sp)
    val body = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W600, fontSize = 16.sp, lineHeight = 23.sp)
    val bodyStrong = body.copy(fontWeight = FontWeight.W800)
    val small = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.W700, fontSize = 14.sp, lineHeight = 19.sp)

    /** Buttons and eyebrow labels. Set in capitals by the caller. */
    val label = TextStyle(
        fontFamily = Nunito,
        fontWeight = FontWeight.W800,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.8.sp,
    )
    val eyebrow = label.copy(fontSize = 13.sp, lineHeight = 16.sp)
}

@Composable
fun InfralingoTheme(content: @Composable () -> Unit) {
    val palette = if (isSystemInDarkTheme()) DarkPalette else LightPalette
    val scheme = if (palette.dark) darkColorScheme() else lightColorScheme()
    MaterialTheme(
        colorScheme = scheme.copy(
            background = palette.background,
            surface = palette.background,
            surfaceContainerLow = palette.background,
            onBackground = palette.text,
            onSurface = palette.text,
            onSurfaceVariant = palette.textSoft,
            primary = palette.green.face,
            onPrimary = palette.onTone,
            error = palette.red.face,
            outline = palette.border,
        ),
    ) {
        CompositionLocalProvider(LocalPalette provides palette, LocalContentColor provides palette.text) {
            ProvideTextStyle(Type.body, content)
        }
    }
}
