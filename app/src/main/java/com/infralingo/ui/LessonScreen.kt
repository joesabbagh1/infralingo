package com.infralingo.ui

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.systemBarsPadding
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import kotlin.random.Random

@Composable
fun LessonScreen(
    ui: LessonUi,
    onSelect: (Int) -> Unit,
    onHint: () -> Unit,
    onCheck: () -> Unit,
    onNext: () -> Unit,
    onClose: () -> Unit,
) {
    val summary = ui.summary
    if (summary != null) {
        BackHandler(onBack = onClose)
        LessonComplete(summary, onClose)
        return
    }

    val palette = LocalPalette.current
    val context = LocalContext.current
    val view = LocalView.current
    var leaving by remember { mutableStateOf(false) }
    BackHandler { leaving = true }

    LaunchedEffect(ui.question.key, ui.feedback?.correct) {
        val correct = ui.feedback?.correct ?: return@LaunchedEffect
        view.performHapticFeedback(
            when {
                Build.VERSION.SDK_INT < Build.VERSION_CODES.R -> HapticFeedbackConstants.VIRTUAL_KEY
                correct -> HapticFeedbackConstants.CONFIRM
                else -> HapticFeedbackConstants.REJECT
            },
        )
    }

    Column(Modifier.fillMaxSize().background(palette.background)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(start = 8.dp, end = 20.dp, top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(48.dp)
                    .clickable(role = Role.Button, onClickLabel = "Leave lesson") { leaving = true },
                contentAlignment = Alignment.Center,
            ) {
                CrossIcon(Modifier.size(26.dp), tint = palette.textFaint)
            }
            Meter(ui.progress, palette.green.face, Modifier.weight(1f), track = palette.border)
        }
        ComboLine(ui.combo)

        AnimatedContent(
            targetState = ui.question,
            contentKey = { it.key },
            transitionSpec = {
                (slideInHorizontally(tween(220)) { it / 3 } + fadeIn(tween(220)))
                    .togetherWith(slideOutHorizontally(tween(160)) { -it / 3 } + fadeOut(tween(120)))
            },
            modifier = Modifier.weight(1f),
            label = "question",
        ) { question ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
            ) {
                QuestionTagLine(question.tag)
                Text(
                    "${question.unitTitle} · ${question.skillTitle}",
                    style = Type.small,
                    color = palette.textSoft,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    question.prompt,
                    style = Type.prompt,
                    color = palette.text,
                    modifier = Modifier.padding(top = 10.dp, bottom = 20.dp),
                )
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    question.choices.forEachIndexed { index, choice ->
                        ChoiceCard(choice, onClick = { onSelect(index) })
                    }
                }
            }
        }

        // The answer panel rises over the action bar and drops back behind it.
        AnimatedContent(
            targetState = ui.feedback,
            contentKey = { it != null },
            transitionSpec = {
                if (targetState != null) {
                    slideInVertically(tween(180)) { it } togetherWith fadeOut(tween(1, delayMillis = 180))
                } else {
                    (fadeIn(tween(1)) togetherWith slideOutVertically(tween(140)) { it })
                        .apply { targetContentZIndex = -1f }
                }
            },
            contentAlignment = Alignment.BottomCenter,
            label = "footer",
        ) { feedback ->
            if (feedback == null) {
                ActionBar(ui.hintsLeft, ui.canCheck, onHint, onCheck)
            } else {
                FeedbackPanel(
                    feedback = feedback,
                    onNext = onNext,
                    onAskAi = {
                        val send = Intent(Intent.ACTION_SEND)
                            .setType("text/plain")
                            .putExtra(Intent.EXTRA_TEXT, feedback.askAi)
                        context.startActivity(Intent.createChooser(send, "Ask an assistant"))
                    },
                    onSource = {
                        try {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(feedback.url)))
                        } catch (_: ActivityNotFoundException) {
                            // No browser on this device. Nothing useful to do with the link.
                        }
                    },
                )
            }
        }
    }

    if (leaving) {
        LeaveSheet(onStay = { leaving = false }, onLeave = onClose)
    }
}

@Composable
private fun ComboLine(combo: Int) {
    val palette = LocalPalette.current
    Box(Modifier.fillMaxWidth().height(26.dp), contentAlignment = Alignment.Center) {
        AnimatedVisibility(
            visible = combo >= 3,
            enter = fadeIn() + scaleIn(initialScale = 0.6f),
            exit = fadeOut(),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                FlameIcon(Modifier.size(18.dp))
                Text(
                    "$combo IN A ROW",
                    style = Type.eyebrow,
                    color = palette.orange.edge,
                    modifier = Modifier.padding(start = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun QuestionTagLine(tag: QuestionTag) {
    val palette = LocalPalette.current
    val (label, color) = when (tag) {
        QuestionTag.NEW -> "New question" to palette.selectedInk
        QuestionTag.REVIEW -> "Review" to palette.correctInk
        QuestionTag.MISTAKE -> "Previous mistake" to palette.orange.edge
        QuestionTag.RETRY -> "One more try" to palette.orange.edge
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        SparkleIcon(Modifier.size(16.dp), tint = color)
        Text(label.uppercase(), style = Type.eyebrow, color = color, modifier = Modifier.padding(start = 6.dp))
    }
}

@Composable
private fun ChoiceCard(choice: ChoiceUi, onClick: () -> Unit) {
    val palette = LocalPalette.current
    val face by animateColorAsState(
        when (choice.state) {
            ChoiceState.SELECTED -> palette.selectedTint
            ChoiceState.CORRECT -> palette.correctTint
            ChoiceState.WRONG -> palette.wrongTint
            else -> palette.background
        },
        tween(120),
        label = "face",
    )
    val edge by animateColorAsState(
        when (choice.state) {
            ChoiceState.SELECTED -> palette.selectedBorder
            ChoiceState.CORRECT -> palette.correctBorder
            ChoiceState.WRONG -> palette.wrongBorder
            else -> palette.border
        },
        tween(120),
        label = "edge",
    )
    val ink = when (choice.state) {
        ChoiceState.IDLE -> palette.text
        ChoiceState.SELECTED -> palette.selectedInk
        ChoiceState.CORRECT -> palette.correctBody
        ChoiceState.WRONG -> palette.wrongBody
        ChoiceState.STRUCK -> palette.textFaint
        ChoiceState.REST -> palette.textSoft
    }
    Chunky(
        face = face,
        edge = edge,
        border = 2.dp,
        lip = 2.dp,
        onClick = onClick,
        enabled = choice.state == ChoiceState.IDLE || choice.state == ChoiceState.SELECTED,
        modifier = Modifier.fillMaxWidth().alpha(if (choice.state == ChoiceState.STRUCK) 0.6f else 1f),
        contentAlignment = Alignment.CenterStart,
    ) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                choice.text,
                style = Type.body,
                color = ink,
                textDecoration = if (choice.state == ChoiceState.STRUCK) TextDecoration.LineThrough else null,
                modifier = Modifier.weight(1f),
            )
            when (choice.state) {
                ChoiceState.CORRECT -> CheckIcon(Modifier.padding(start = 10.dp).size(22.dp), tint = palette.correctInk)
                ChoiceState.WRONG -> CrossIcon(Modifier.padding(start = 10.dp).size(22.dp), tint = palette.wrongInk)
                else -> Unit
            }
        }
    }
}

@Composable
private fun ActionBar(hintsLeft: Int, canCheck: Boolean, onHint: () -> Unit, onCheck: () -> Unit) {
    val palette = LocalPalette.current
    Column(Modifier.fillMaxWidth().background(palette.background)) {
        Box(Modifier.fillMaxWidth().height(2.dp).background(palette.border))
        Row(
            modifier = Modifier.navigationBarsPadding().padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Chunky(
                face = palette.background,
                edge = palette.border,
                border = 2.dp,
                lip = 2.dp,
                onClick = onHint,
                enabled = hintsLeft > 0,
                modifier = Modifier.height(52.dp),
            ) {
                Row(Modifier.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    BulbIcon(Modifier.size(26.dp), lit = hintsLeft > 0)
                    Text(
                        "HINT",
                        style = Type.label,
                        color = if (hintsLeft > 0) palette.textSoft else palette.idleText,
                        modifier = Modifier.padding(start = 6.dp),
                    )
                    Text(
                        "$hintsLeft",
                        style = Type.eyebrow,
                        color = if (hintsLeft > 0) palette.text else palette.idleText,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .padding(start = 8.dp)
                            .background(palette.raised, CircleShape)
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
            DuoButton("Check", onCheck, Modifier.weight(1f), enabled = canCheck)
        }
    }
}

@Composable
private fun FeedbackPanel(feedback: FeedbackUi, onNext: () -> Unit, onAskAi: () -> Unit, onSource: () -> Unit) {
    val palette = LocalPalette.current
    val tint = if (feedback.correct) palette.correctTint else palette.wrongTint
    val ink = if (feedback.correct) palette.correctInk else palette.wrongInk
    val body = if (feedback.correct) palette.correctBody else palette.wrongBody
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(tint)
            .navigationBarsPadding()
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(32.dp).background(ink, CircleShape), contentAlignment = Alignment.Center) {
                if (feedback.correct) {
                    CheckIcon(Modifier.size(20.dp), tint = tint)
                } else {
                    CrossIcon(Modifier.size(18.dp), tint = tint)
                }
            }
            Text(feedback.title, style = Type.title, color = ink, modifier = Modifier.padding(start = 10.dp).weight(1f))
            if (feedback.xp > 0) Text("+${feedback.xp} XP", style = Type.label, color = ink)
        }
        Column(
            modifier = Modifier
                .padding(top = 10.dp)
                .heightIn(max = 230.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            if (!feedback.correct) {
                Text("Correct answer", style = Type.bodyStrong, color = ink)
                Text(feedback.answer, style = Type.body, color = body, modifier = Modifier.padding(bottom = 10.dp))
            }
            Text(feedback.explanation, style = Type.body, color = body)
            if (feedback.note != null) {
                Text(feedback.note, style = Type.small, color = ink, modifier = Modifier.padding(top = 8.dp))
            }
        }
        Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            PanelLink("Ask AI", ink, onAskAi) { SparkleIcon(Modifier.size(18.dp), tint = ink) }
            if (feedback.url.isNotBlank()) {
                PanelLink(feedback.source, ink, onSource) { LinkIcon(Modifier.size(16.dp), tint = ink) }
            }
        }
        DuoButton(
            text = if (feedback.correct) "Continue" else "Got it",
            onClick = onNext,
            tone = if (feedback.correct) palette.green else palette.red,
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
        )
    }
}

@Composable
private fun PanelLink(text: String, color: Color, onClick: () -> Unit, icon: @Composable () -> Unit) {
    Row(
        modifier = Modifier
            .heightIn(min = 44.dp)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon()
        Text(text.uppercase(), style = Type.eyebrow, color = color, modifier = Modifier.padding(start = 6.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LeaveSheet(onStay: () -> Unit, onLeave: () -> Unit) {
    val palette = LocalPalette.current
    ModalBottomSheet(
        onDismissRequest = onStay,
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
            Mascot(Modifier.size(96.dp), Mood.OOPS)
            Text(
                "Leave the lesson?",
                style = Type.title,
                color = palette.text,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                "Your answers so far are saved. The questions you have not reached will still be here.",
                style = Type.body,
                color = palette.textSoft,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp, bottom = 20.dp),
            )
            DuoButton("Keep learning", onStay, Modifier.fillMaxWidth(), tone = palette.blue)
            GhostButton(
                "End lesson",
                onLeave,
                Modifier.fillMaxWidth().padding(top = 10.dp),
                color = palette.wrongInk,
            )
        }
    }
}

@Composable
private fun LessonComplete(summary: SummaryUi, onDone: () -> Unit) {
    val palette = LocalPalette.current
    var counting by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { counting = true }
    val xp by animateIntAsState(if (counting) summary.xp else 0, tween(900), label = "xp")
    val accuracy by animateIntAsState(if (counting) summary.accuracy else 0, tween(900), label = "accuracy")

    Box(Modifier.fillMaxSize().background(palette.background)) {
        Confetti(listOf(palette.green, palette.blue, palette.gold, palette.red, palette.unit(1)).map { it.face })
        Column(
            modifier = Modifier.fillMaxSize().systemBarsPadding().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Mascot(Modifier.size(150.dp), Mood.CHEER)
                Text(
                    summary.title,
                    style = Type.display,
                    color = if (palette.dark) palette.gold.face else palette.gold.edge,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 12.dp),
                )
                Text(
                    when {
                        summary.accuracy == 100 -> "Flawless. Every answer right the first time."
                        summary.accuracy >= 80 -> "Strong work. Anything shaky comes back tomorrow."
                        else -> "The shaky ones come back tomorrow."
                    },
                    style = Type.body,
                    color = palette.textSoft,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 6.dp, bottom = 24.dp),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    ResultTile("Total XP", palette.gold, "$xp", Modifier.weight(1f)) { BoltIcon(Modifier.size(22.dp)) }
                    ResultTile("Accuracy", palette.green, "$accuracy%", Modifier.weight(1f)) {
                        TargetIcon(Modifier.size(20.dp))
                    }
                    ResultTile(
                        "Time",
                        palette.blue,
                        "%d:%02d".format(summary.seconds / 60, summary.seconds % 60),
                        Modifier.weight(1f),
                    ) { ClockIcon(Modifier.size(20.dp)) }
                }
                if (summary.streakExtended || summary.goalReached || summary.bestCombo >= 3) {
                    Panel(Modifier.fillMaxWidth().padding(top = 16.dp)) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            if (summary.streakExtended) {
                                ResultLine("${summary.streak} day streak") { FlameIcon(Modifier.size(24.dp)) }
                            }
                            if (summary.goalReached) {
                                ResultLine("Daily goal reached: ${summary.todayXp} of ${summary.dailyGoal} XP") {
                                    GoalRing(summary.todayXp, summary.dailyGoal, Modifier.size(24.dp))
                                }
                            }
                            if (summary.bestCombo >= 3) {
                                ResultLine("${summary.bestCombo} right in a row") {
                                    StarIcon(Modifier.size(24.dp), tint = palette.gold.face)
                                }
                            }
                        }
                    }
                }
                if (summary.revisit.isNotEmpty()) {
                    Panel(Modifier.fillMaxWidth().padding(top = 12.dp)) {
                        Text("WORTH ANOTHER LOOK", style = Type.eyebrow, color = palette.textSoft)
                        Text(
                            summary.revisit.joinToString(" · "),
                            style = Type.body,
                            color = palette.text,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
            DuoButton("Continue", onDone, Modifier.fillMaxWidth().padding(top = 16.dp))
        }
    }
}

@Composable
private fun ResultTile(
    label: String,
    tone: Tone,
    value: String,
    modifier: Modifier = Modifier,
    icon: @Composable () -> Unit,
) {
    val palette = LocalPalette.current
    Column(
        modifier = modifier.background(tone.face, RoundedCornerShape(16.dp)).padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            label.uppercase(),
            style = Type.eyebrow.copy(letterSpacing = Type.small.letterSpacing),
            color = palette.onTone,
            modifier = Modifier.padding(vertical = 5.dp),
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(palette.background, RoundedCornerShape(14.dp))
                .padding(vertical = 16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            icon()
            Spacer(Modifier.width(6.dp))
            Text(value, style = Type.heading, color = palette.text)
        }
    }
}

@Composable
private fun ResultLine(text: String, icon: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        icon()
        Text(
            text,
            style = Type.bodyStrong,
            color = LocalPalette.current.text,
            modifier = Modifier.padding(start = 10.dp),
        )
    }
}

private class Piece(
    val x: Float,
    val delay: Float,
    val fall: Float,
    val drift: Float,
    val width: Float,
    val height: Float,
    val turns: Float,
    val color: Int,
)

/** One burst of paper falling from the top of the screen. */
@Composable
private fun Confetti(colors: List<Color>) {
    val pieces = remember {
        List(80) {
            Piece(
                x = Random.nextFloat(),
                delay = Random.nextFloat() * 0.3f,
                fall = 0.8f + Random.nextFloat() * 0.6f,
                drift = (Random.nextFloat() - 0.5f) * 0.3f,
                width = 8f + Random.nextFloat() * 8f,
                height = 12f + Random.nextFloat() * 12f,
                turns = 1f + Random.nextFloat() * 3f,
                color = Random.nextInt(colors.size),
            )
        }
    }
    val time = remember { Animatable(0f) }
    LaunchedEffect(Unit) { time.animateTo(1f, tween(2800, easing = LinearEasing)) }
    Canvas(Modifier.fillMaxSize()) {
        if (time.value >= 1f) return@Canvas
        pieces.forEach { piece ->
            val along = ((time.value - piece.delay) / (1f - piece.delay)).coerceIn(0f, 1f) * piece.fall
            if (along <= 0f) return@forEach
            val centre = Offset(
                x = (piece.x + piece.drift * along) * size.width,
                y = along * size.height * 1.15f - piece.height,
            )
            rotate(piece.turns * along * 360f, centre) {
                drawRect(
                    color = colors[piece.color],
                    topLeft = Offset(centre.x - piece.width / 2, centre.y - piece.height / 2),
                    size = Size(piece.width, piece.height),
                    alpha = (1.6f - along * 1.4f).coerceIn(0f, 1f),
                )
            }
        }
    }
}
