package com.infralingo.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale

enum class Mood { HAPPY, CHEER, OOPS }

private val Ink = Color(0xFF3C3C3C)
private val Blush = Color(0xFFFF9DB5)
private val Lamp = Color(0xFFFFC800)
private val Led = Color(0xFF1CB0F6)

/** The mascot: a little server with a face. Drawn on a 100 by 100 grid. */
@Composable
fun Mascot(
    modifier: Modifier = Modifier,
    mood: Mood = Mood.HAPPY,
    body: Tone = LocalPalette.current.green,
) {
    Canvas(modifier) {
        scale(size.minDimension / 100f, pivot = Offset.Zero) {
            drawLine(body.edge, Offset(50f, 20f), Offset(50f, 10f), strokeWidth = 4f, cap = StrokeCap.Round)
            drawCircle(Lamp, 5.5f, Offset(50f, 8f))
            block(body.edge, 9f, 40f, 10f, 20f, 4f)
            block(body.edge, 81f, 40f, 10f, 20f, 4f)
            block(body.edge, 30f, 84f, 14f, 9f, 4f)
            block(body.edge, 56f, 84f, 14f, 9f, 4f)
            block(body.edge, 16f, 23f, 68f, 66f, 20f)
            block(body.face, 16f, 18f, 68f, 66f, 20f)
            block(Color.White, 25f, 28f, 50f, 38f, 13f)
            drawCircle(Blush, 3.4f, Offset(31.5f, 55f))
            drawCircle(Blush, 3.4f, Offset(68.5f, 55f))
            face(mood)
            drawCircle(Lamp, 2.6f, Offset(40f, 75.5f))
            drawCircle(Color.White.copy(alpha = 0.9f), 2.6f, Offset(50f, 75.5f))
            drawCircle(Led, 2.6f, Offset(60f, 75.5f))
        }
    }
}

private fun DrawScope.block(color: Color, x: Float, y: Float, width: Float, height: Float, radius: Float) {
    drawRoundRect(color, Offset(x, y), Size(width, height), CornerRadius(radius))
}

private fun DrawScope.curve(startAngle: Float, x: Float, y: Float, width: Float, height: Float) {
    drawArc(
        color = Ink,
        startAngle = startAngle,
        sweepAngle = 140f,
        useCenter = false,
        topLeft = Offset(x, y),
        size = Size(width, height),
        style = Stroke(3.2f, cap = StrokeCap.Round),
    )
}

private fun DrawScope.face(mood: Mood) {
    when (mood) {
        Mood.HAPPY -> {
            eye(39f, 44.5f)
            eye(61f, 44.5f)
            curve(20f, 43f, 46f, 14f, 12f)
        }
        Mood.CHEER -> {
            curve(200f, 33.5f, 41f, 11f, 10f)
            curve(200f, 55.5f, 41f, 11f, 10f)
            drawArc(Ink, 0f, 180f, useCenter = true, topLeft = Offset(42.5f, 46f), size = Size(15f, 15f))
        }
        Mood.OOPS -> {
            eye(39f, 46f)
            eye(61f, 46f)
            curve(200f, 43.5f, 55f, 13f, 10f)
        }
    }
}

private fun DrawScope.eye(x: Float, y: Float) {
    drawCircle(Ink, 5.6f, Offset(x, y))
    drawCircle(Color.White, 1.9f, Offset(x + 1.8f, y - 1.9f))
}
