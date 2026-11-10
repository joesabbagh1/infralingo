package com.infralingo.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.infralingo.domain.LessonSpec

@Composable
fun PracticeScreen(practice: PracticeUi, onStart: (LessonSpec) -> Unit) {
    val palette = LocalPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column {
            SectionTitle("Practice")
            Text(
                "Short sessions that stop what you learned from fading.",
                style = Type.body,
                color = palette.textSoft,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        ReviewCard(practice, onStart = { onStart(LessonSpec.Review) })
        ActionRow(
            title = "Mistakes",
            detail = when (practice.mistakes) {
                0 -> "Nothing to fix right now."
                1 -> "1 question you missed or needed a hint on."
                else -> "${practice.mistakes} questions you missed or needed a hint on."
            },
            enabled = practice.mistakes > 0,
            onClick = { onStart(LessonSpec.Mistakes) },
        ) {
            Badge(if (practice.mistakes > 0) palette.red.face else palette.idle.face) {
                CrossIcon(Modifier.size(24.dp), tint = if (practice.mistakes > 0) palette.onTone else palette.idleText)
            }
        }

        SectionTitle("Weak spots", Modifier.padding(top = 10.dp))
        if (practice.weakSpots.isEmpty()) {
            Text(
                "Skills where your recent answers slip below 70% show up here, ready to drill.",
                style = Type.body,
                color = palette.textSoft,
            )
        }
        practice.weakSpots.forEach { spot ->
            val tone = palette.unit(spot.unitIndex)
            ActionRow(
                title = spot.title,
                detail = "${spot.unitTitle} · ${spot.percent}% right lately",
                enabled = true,
                onClick = { onStart(LessonSpec.SkillLesson(spot.skillId)) },
                meter = { Meter(spot.percent / 100f, tone.face, height = 10.dp, gloss = false) },
            ) {
                Badge(tone.face) { DumbbellIcon(Modifier.size(26.dp), tint = palette.onTone) }
            }
        }
    }
}

@Composable
private fun ReviewCard(practice: PracticeUi, onStart: () -> Unit) {
    val palette = LocalPalette.current
    val tone = palette.blue
    val title = when {
        practice.due == 1 -> "1 question is due"
        practice.due > 1 -> "${practice.due} questions are due"
        practice.seen > 0 -> "All caught up"
        else -> "Nothing to review yet"
    }
    val detail = when {
        practice.due > 0 -> "Answering them today is what moves them into long-term memory."
        practice.seen > 0 -> "The next review is ${practice.nextDueIn?.let(::until) ?: "a while away"}."
        else -> "Finish a lesson and its questions come back here on a schedule."
    }
    Column(Modifier.fillMaxWidth().background(tone.face, RoundedCornerShape(16.dp)).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("SPACED REVIEW", style = Type.eyebrow, color = palette.onTone)
                Text(title, style = Type.title, color = palette.onTone)
                Text(detail, style = Type.body, color = palette.onTone, modifier = Modifier.padding(top = 4.dp))
            }
            Mascot(
                modifier = Modifier.padding(start = 8.dp).size(84.dp),
                mood = if (practice.due > 0) Mood.HAPPY else Mood.CHEER,
                body = palette.gold,
            )
        }
        if (practice.seen > 0) {
            Chunky(
                face = if (palette.dark) palette.background else Color.White,
                edge = Color.Black.copy(alpha = 0.2f),
                onClick = onStart,
                modifier = Modifier.fillMaxWidth().padding(top = 14.dp).height(50.dp),
            ) {
                Text(
                    if (practice.due > 0) "REVIEW NOW" else "PRACTICE ANYWAY",
                    style = Type.label,
                    color = if (palette.dark) tone.face else tone.edge,
                )
            }
        }
    }
}

private fun until(millis: Long): String {
    val minutes = millis / 60_000
    return when {
        minutes < 60 -> "in ${minutes.coerceAtLeast(1)} min"
        minutes < 48 * 60 -> "in ${minutes / 60} h"
        else -> "in ${minutes / (24 * 60)} days"
    }
}

@Composable
private fun Badge(color: Color, content: @Composable () -> Unit) {
    Box(Modifier.size(48.dp).background(color, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
        content()
    }
}

/** A pressable row: a badge, two lines of text, and a chevron when there is somewhere to go. */
@Composable
fun ActionRow(
    title: String,
    detail: String,
    enabled: Boolean,
    onClick: () -> Unit,
    meter: (@Composable () -> Unit)? = null,
    badge: @Composable () -> Unit,
) {
    val palette = LocalPalette.current
    Chunky(
        face = palette.background,
        edge = palette.border,
        border = 2.dp,
        lip = 2.dp,
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = Alignment.CenterStart,
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            badge()
            Column(Modifier.padding(start = 12.dp).weight(1f)) {
                Text(title, style = Type.bodyStrong, color = if (enabled) palette.text else palette.textSoft)
                Text(detail, style = Type.small, color = palette.textSoft)
                if (meter != null) {
                    Box(Modifier.padding(top = 6.dp)) { meter() }
                }
            }
            if (enabled) ChevronIcon(Modifier.padding(start = 8.dp).size(22.dp), tint = palette.textFaint)
        }
    }
}
