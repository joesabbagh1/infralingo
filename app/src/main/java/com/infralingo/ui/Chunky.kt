package com.infralingo.ui

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp

/**
 * The raised slab everything pressable is made of: a [face] sitting on an [edge] that shows as a lip along the
 * bottom. Pressing sinks the face onto the lip. With a [border] the edge also outlines the face.
 */
@Composable
fun Chunky(
    face: Color,
    edge: Color,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    enabled: Boolean = true,
    border: Dp = 0.dp,
    lip: Dp = 4.dp,
    radius: Dp = 16.dp,
    contentAlignment: Alignment = Alignment.Center,
    content: @Composable BoxScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val sink by animateDpAsState(if (pressed && enabled) lip else 0.dp, tween(60), label = "sink")
    val click = if (onClick == null) {
        Modifier
    } else {
        Modifier.clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
    }
    Box(
        modifier = modifier
            .then(click)
            .drawBehind {
                val down = sink.toPx()
                val line = border.toPx()
                val corner = radius.toPx()
                drawRoundRect(
                    color = edge,
                    topLeft = Offset(0f, down),
                    size = Size(size.width, size.height - down),
                    cornerRadius = CornerRadius(corner),
                )
                drawRoundRect(
                    color = face,
                    topLeft = Offset(line, down + line),
                    size = Size(size.width - 2 * line, size.height - lip.toPx() - 2 * line),
                    cornerRadius = CornerRadius((corner - line).coerceAtLeast(0f)),
                )
            }
            .padding(bottom = lip)
            .offset { IntOffset(0, sink.roundToPx()) }
            .padding(border),
        contentAlignment = contentAlignment,
        content = content,
    )
}

@Composable
fun DuoButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tone: Tone = LocalPalette.current.green,
    enabled: Boolean = true,
) {
    val palette = LocalPalette.current
    Chunky(
        face = if (enabled) tone.face else palette.idle.face,
        edge = if (enabled) tone.edge else palette.idle.face,
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.heightIn(min = 52.dp),
    ) {
        Text(
            text.uppercase(),
            style = Type.label,
            color = if (enabled) palette.onTone else palette.idleText,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
        )
    }
}

/** The quieter button: page-coloured face, grey outline, coloured label. */
@Composable
fun GhostButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = LocalPalette.current.selectedInk,
    enabled: Boolean = true,
) {
    val palette = LocalPalette.current
    Chunky(
        face = palette.background,
        edge = palette.border,
        border = 2.dp,
        lip = 2.dp,
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.heightIn(min = 52.dp),
    ) {
        Text(
            text.uppercase(),
            style = Type.label,
            color = if (enabled) color else palette.idleText,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp),
        )
    }
}

/** A flat outlined card for content that is read, not pressed. */
@Composable
fun Panel(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .border(2.dp, LocalPalette.current.border, RoundedCornerShape(16.dp))
            .padding(16.dp),
        content = content,
    )
}

/** A progress track. The unfilled part is a lighter step of the fill unless [track] says otherwise. */
@Composable
fun Meter(
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier,
    track: Color = color.copy(alpha = 0.22f),
    height: Dp = 16.dp,
    gloss: Boolean = true,
) {
    val shown by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = spring(Spring.DampingRatioNoBouncy, Spring.StiffnessLow),
        label = "meter",
    )
    Canvas(modifier.fillMaxWidth().height(height)) {
        val round = CornerRadius(size.height / 2)
        drawRoundRect(track, cornerRadius = round)
        if (shown > 0f) {
            val width = (size.width * shown).coerceAtLeast(size.height)
            drawRoundRect(color, size = Size(width, size.height), cornerRadius = round)
            if (gloss && width > size.height * 1.5f) {
                drawRoundRect(
                    color = Color.White.copy(alpha = 0.28f),
                    topLeft = Offset(size.height * 0.5f, size.height * 0.25f),
                    size = Size(width - size.height, size.height * 0.25f),
                    cornerRadius = round,
                )
            }
        }
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, style = Type.title, color = LocalPalette.current.text, modifier = modifier)
}

@Composable
fun IconLabel(
    icon: @Composable () -> Unit,
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        icon()
        Text(text, style = Type.heading, color = color)
    }
}
