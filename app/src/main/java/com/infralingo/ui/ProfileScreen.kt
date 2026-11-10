package com.infralingo.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.infralingo.domain.DAILY_GOALS
import java.text.NumberFormat

@Composable
fun ProfileScreen(
    stats: TopStats,
    units: List<UnitUi>,
    profile: ProfileUi,
    onGoal: (Int) -> Unit,
    onExport: () -> Unit,
    onImport: () -> Unit,
) {
    val palette = LocalPalette.current
    val number = NumberFormat.getIntegerInstance()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SectionTitle("Your progress")
        // Each pair shares the height of its taller tile.
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val tile = Modifier.weight(1f).fillMaxHeight()
            StatTile("${stats.streak}", "Day streak", tile) { FlameIcon(Modifier.size(30.dp), lit = stats.streak > 0) }
            StatTile(number.format(stats.totalXp), "Total XP", tile) { BoltIcon(Modifier.size(30.dp)) }
        }
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val tile = Modifier.weight(1f).fillMaxHeight()
            StatTile(profile.accuracy?.let { "$it%" } ?: "–", "First-try accuracy", tile) {
                TargetIcon(Modifier.size(28.dp))
            }
            StatTile("${profile.learned}/${profile.questions}", "Questions learned", tile) {
                StarIcon(Modifier.size(30.dp), tint = palette.gold.face)
            }
        }

        SectionTitle("This week", Modifier.padding(top = 12.dp))
        Panel(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                profile.week.forEach { day -> DayDot(day) }
            }
            Box(Modifier.padding(vertical = 14.dp).fillMaxWidth().height(2.dp).background(palette.border))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Daily goal", style = Type.bodyStrong, color = palette.text, modifier = Modifier.weight(1f))
                Text("${stats.todayXp} of ${stats.dailyGoal} XP today", style = Type.small, color = palette.textSoft)
            }
            Meter(
                progress = stats.todayXp.toFloat() / stats.dailyGoal.coerceAtLeast(1),
                color = palette.blue.face,
                modifier = Modifier.padding(top = 8.dp),
            )
            Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DAILY_GOALS.forEach { goal ->
                    val picked = goal == stats.dailyGoal
                    Chunky(
                        face = if (picked) palette.selectedTint else palette.background,
                        edge = if (picked) palette.selectedBorder else palette.border,
                        border = 2.dp,
                        lip = 2.dp,
                        radius = 12.dp,
                        onClick = { onGoal(goal) },
                        modifier = Modifier.weight(1f).height(44.dp),
                    ) {
                        val ink = if (picked) palette.selectedInk else palette.textSoft
                        Text("$goal XP", style = Type.eyebrow, color = ink)
                    }
                }
            }
        }

        SectionTitle("Units", Modifier.padding(top = 12.dp))
        Panel(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                units.forEach { unit ->
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                unit.title,
                                style = Type.bodyStrong,
                                color = palette.text,
                                modifier = Modifier.weight(1f),
                            )
                            Text("${unit.learned}/${unit.total}", style = Type.small, color = palette.textSoft)
                        }
                        Meter(
                            progress = unit.learned.toFloat() / unit.total.coerceAtLeast(1),
                            color = palette.unit(unit.index).face,
                            height = 12.dp,
                            gloss = false,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                }
            }
        }

        if (profile.strengths.isNotEmpty()) {
            SectionTitle("Strongest skills", Modifier.padding(top = 12.dp))
            Panel(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    profile.strengths.forEach { skill ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(skill.title, style = Type.bodyStrong, color = palette.text)
                                Text(skill.unitTitle, style = Type.small, color = palette.textSoft)
                            }
                            Text("${skill.percent}%", style = Type.heading, color = palette.text)
                        }
                    }
                }
            }
        }

        if (profile.mistakes.isNotEmpty()) {
            SectionTitle("Open mistakes", Modifier.padding(top = 12.dp))
            Panel(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    profile.mistakes.forEach { miss ->
                        Column {
                            Text(miss.skillTitle.uppercase(), style = Type.eyebrow, color = palette.wrongInk)
                            Text(miss.prompt, style = Type.body, color = palette.text)
                        }
                    }
                }
            }
        }

        SectionTitle("Backup", Modifier.padding(top = 12.dp))
        Text(
            "Progress lives on this phone only. Export a file to keep a copy or move to another device.",
            style = Type.body,
            color = palette.textSoft,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GhostButton("Export", onExport, Modifier.weight(1f))
            GhostButton("Import", onImport, Modifier.weight(1f))
        }
    }
}

/** A headline number: the value in ink, a short label under it, and a coloured mark beside them. */
@Composable
private fun StatTile(value: String, label: String, modifier: Modifier = Modifier, icon: @Composable () -> Unit) {
    val palette = LocalPalette.current
    Row(
        modifier = modifier
            .border(2.dp, palette.border, RoundedCornerShape(16.dp))
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon()
        Column(Modifier.padding(start = 10.dp)) {
            Text(value, style = Type.heading, color = palette.text)
            Text(label, style = Type.small, color = palette.textSoft)
        }
    }
}

@Composable
private fun DayDot(day: DayUi) {
    val palette = LocalPalette.current
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            day.label,
            style = Type.eyebrow,
            color = if (day.today) palette.text else palette.textSoft,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(34.dp).padding(bottom = 6.dp),
        )
        Box(
            modifier = Modifier
                .size(34.dp)
                .background(if (day.practiced) palette.orange.face else palette.idle.face, CircleShape)
                .then(if (day.today) Modifier.border(2.dp, palette.text, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            if (day.practiced) CheckIcon(Modifier.size(20.dp), tint = palette.onTone)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReplaceProgressSheet(onReplace: () -> Unit, onCancel: () -> Unit) {
    val palette = LocalPalette.current
    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = palette.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Replace your progress?", style = Type.title, color = palette.text)
            Text(
                "Everything tracked on this phone is swapped for what is in the backup. This cannot be undone.",
                style = Type.body,
                color = palette.textSoft,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp, bottom = 20.dp),
            )
            DuoButton("Replace progress", onReplace, Modifier.fillMaxWidth(), tone = palette.red)
            GhostButton("Cancel", onCancel, Modifier.fillMaxWidth().padding(top = 10.dp), color = palette.textSoft)
        }
    }
}
