package com.infralingo.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// Every icon is drawn on a 24 by 24 grid and scaled to whatever size the caller gives it.

private val Flame = Color(0xFFFF9600)
private val Sun = Color(0xFFFFC800)
private val Sky = Color(0xFF1CB0F6)
private val Cherry = Color(0xFFFF4B4B)
private val Ash = Color(0xFFAFAFAF)

@Composable
private fun Glyph(modifier: Modifier, draw: DrawScope.() -> Unit) {
    Canvas(modifier) {
        scale(size.minDimension / 24f, pivot = Offset.Zero) { draw() }
    }
}

private fun path(build: Path.() -> Unit): Path = Path().apply(build)

private fun polygon(vararg points: Pair<Float, Float>): Path = path {
    moveTo(points.first().first, points.first().second)
    points.drop(1).forEach { (x, y) -> lineTo(x, y) }
    close()
}

/** Fills a shape and strokes it in the same colour, which rounds off its corners. */
private fun DrawScope.soft(shape: Path, color: Color, round: Float = 1.4f) {
    drawPath(shape, color)
    drawPath(shape, color, style = Stroke(round, join = StrokeJoin.Round))
}

private fun DrawScope.line(color: Color, width: Float, vararg points: Pair<Float, Float>) {
    val stroke = path {
        moveTo(points.first().first, points.first().second)
        points.drop(1).forEach { (x, y) -> lineTo(x, y) }
    }
    drawPath(stroke, color, style = Stroke(width, cap = StrokeCap.Round, join = StrokeJoin.Round))
}

private fun DrawScope.pill(color: Color, x: Float, y: Float, width: Float, height: Float, radius: Float) {
    drawRoundRect(color, Offset(x, y), Size(width, height), CornerRadius(radius))
}

private val FlameOuter = path {
    moveTo(12f, 1.8f)
    cubicTo(12.6f, 5.4f, 16.8f, 7.6f, 18.6f, 11.6f)
    cubicTo(20.6f, 16.2f, 17.4f, 22f, 12f, 22f)
    cubicTo(6.8f, 22f, 3.6f, 17.6f, 5f, 12.8f)
    cubicTo(5.6f, 10.6f, 7.2f, 9.2f, 7.6f, 7.2f)
    cubicTo(8.8f, 8.2f, 9.4f, 9.2f, 9.8f, 10.4f)
    cubicTo(10.6f, 7.6f, 11.8f, 5f, 12f, 1.8f)
    close()
}

private val FlameInner = path {
    moveTo(12f, 12.2f)
    cubicTo(13.2f, 13.8f, 15.2f, 15.2f, 15.2f, 17.4f)
    cubicTo(15.2f, 19.4f, 13.8f, 20.6f, 12f, 20.6f)
    cubicTo(10.2f, 20.6f, 8.8f, 19.4f, 8.8f, 17.4f)
    cubicTo(8.8f, 15.2f, 10.8f, 13.8f, 12f, 12.2f)
    close()
}

private val Bolt = polygon(14f to 2f, 5.2f to 13.4f, 10.8f to 13.4f, 9.6f to 22f, 18.8f to 10.2f, 13f to 10.2f)

private val StarShape = path {
    for (point in 0 until 10) {
        val radius = if (point % 2 == 0) 9.6f else 4.6f
        val angle = -PI / 2 + point * PI / 5
        val x = 12f + radius * cos(angle).toFloat()
        val y = 12.8f + radius * sin(angle).toFloat()
        if (point == 0) moveTo(x, y) else lineTo(x, y)
    }
    close()
}

private val Crown = polygon(
    3.6f to 8.4f,
    8f to 12.4f,
    12f to 5.4f,
    16f to 12.4f,
    20.4f to 8.4f,
    18.6f to 18.6f,
    5.4f to 18.6f,
)

private val Cup = path {
    moveTo(7f, 4f)
    lineTo(17f, 4f)
    lineTo(17f, 10f)
    cubicTo(17f, 12.8f, 14.8f, 15f, 12f, 15f)
    cubicTo(9.2f, 15f, 7f, 12.8f, 7f, 10f)
    close()
}

private val House = polygon(
    12f to 3.2f,
    21f to 11.2f,
    18.6f to 11.2f,
    18.6f to 20.2f,
    14f to 20.2f,
    14f to 14.6f,
    10f to 14.6f,
    10f to 20.2f,
    5.4f to 20.2f,
    5.4f to 11.2f,
    3f to 11.2f,
)

private val Shoulders = path {
    moveTo(4.4f, 20.6f)
    cubicTo(4.4f, 16.6f, 7.8f, 14.4f, 12f, 14.4f)
    cubicTo(16.2f, 14.4f, 19.6f, 16.6f, 19.6f, 20.6f)
    close()
}

private val Sparkle = path {
    moveTo(12f, 2.6f)
    cubicTo(12.7f, 8f, 16f, 11.3f, 21.4f, 12f)
    cubicTo(16f, 12.7f, 12.7f, 16f, 12f, 21.4f)
    cubicTo(11.3f, 16f, 8f, 12.7f, 2.6f, 12f)
    cubicTo(8f, 11.3f, 11.3f, 8f, 12f, 2.6f)
    close()
}

@Composable
fun FlameIcon(modifier: Modifier = Modifier, lit: Boolean = true) = Glyph(modifier) {
    drawPath(FlameOuter, if (lit) Flame else Ash)
    drawPath(FlameInner, if (lit) Sun else Color.White.copy(alpha = 0.55f))
}

@Composable
fun BoltIcon(modifier: Modifier = Modifier, tint: Color = Sun) = Glyph(modifier) {
    soft(Bolt, tint)
}

@Composable
fun StarIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    soft(StarShape, tint, round = 2f)
}

@Composable
fun CrownIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    soft(Crown, tint, round = 2f)
}

@Composable
fun CheckIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    line(tint, 3.6f, 5.4f to 12.6f, 10f to 17.2f, 18.6f to 7.4f)
}

@Composable
fun CrossIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    line(tint, 3.2f, 6.2f to 6.2f, 17.8f to 17.8f)
    line(tint, 3.2f, 17.8f to 6.2f, 6.2f to 17.8f)
}

@Composable
fun TrophyIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    soft(Cup, tint, round = 1.2f)
    line(tint, 2f, 7f to 6f, 4.4f to 6f, 4.4f to 8f, 5.4f to 10.2f, 7.6f to 11.2f)
    line(tint, 2f, 17f to 6f, 19.6f to 6f, 19.6f to 8f, 18.6f to 10.2f, 16.4f to 11.2f)
    pill(tint, 11f, 14.6f, 2f, 4f, 0f)
    pill(tint, 7.6f, 18.2f, 8.8f, 2.8f, 1.2f)
}

@Composable
fun DumbbellIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    pill(tint, 6f, 10.8f, 12f, 2.4f, 1f)
    pill(tint, 4.8f, 6f, 3.6f, 12f, 1.5f)
    pill(tint, 15.6f, 6f, 3.6f, 12f, 1.5f)
    pill(tint, 2f, 8.6f, 2.6f, 6.8f, 1.2f)
    pill(tint, 19.4f, 8.6f, 2.6f, 6.8f, 1.2f)
}

@Composable
fun BulbIcon(modifier: Modifier = Modifier, lit: Boolean = true) = Glyph(modifier) {
    val glass = if (lit) Sun else Ash
    drawCircle(glass, 6.6f, Offset(12f, 9.4f))
    pill(glass, 9.2f, 13.6f, 5.6f, 3.4f, 0.6f)
    if (lit) drawCircle(Color.White.copy(alpha = 0.75f), 1.5f, Offset(9.8f, 7.2f))
    pill(Ash, 9.2f, 17.8f, 5.6f, 1.8f, 0.9f)
    pill(Ash, 10.4f, 20.2f, 3.2f, 1.6f, 0.8f)
}

@Composable
fun TargetIcon(modifier: Modifier = Modifier) = Glyph(modifier) {
    drawCircle(Cherry, 10f, Offset(12f, 12f))
    drawCircle(Color.White, 6.8f, Offset(12f, 12f))
    drawCircle(Cherry, 3.6f, Offset(12f, 12f))
}

@Composable
fun ClockIcon(modifier: Modifier = Modifier) = Glyph(modifier) {
    drawCircle(Sky, 10f, Offset(12f, 12f))
    line(Color.White, 2.4f, 12f to 6.8f, 12f to 12f, 15.6f to 14.2f)
}

@Composable
fun HomeIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    soft(House, tint, round = 1.6f)
}

@Composable
fun PersonIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    drawCircle(tint, 4.4f, Offset(12f, 8f))
    soft(Shoulders, tint, round = 1.2f)
}

@Composable
fun SparkleIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    soft(Sparkle, tint, round = 0.8f)
}

@Composable
fun LinkIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    line(tint, 2.6f, 9.4f to 6.4f, 17.6f to 6.4f, 17.6f to 14.6f)
    line(tint, 2.6f, 17.2f to 6.8f, 6.6f to 17.4f)
}

@Composable
fun ChevronIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    line(tint, 2.8f, 9f to 5.6f, 15.4f to 12f, 9f to 18.4f)
}

@Composable
fun MenuIcon(modifier: Modifier = Modifier, tint: Color) = Glyph(modifier) {
    line(tint, 2.6f, 5f to 7f, 19f to 7f)
    line(tint, 2.6f, 5f to 12f, 19f to 12f)
    line(tint, 2.6f, 5f to 17f, 19f to 17f)
}
