package com.infralingo.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.infralingo.domain.LessonSpec
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val NodeLip = 8.dp

// How far each step of the path swings from the centre line, in dp. Odd units mirror it.
private val Wave = listOf(0, 44, 70, 44, 0, -44, -70, -44)

private fun sway(unit: Int, step: Int): Dp = (Wave[step % Wave.size] * if (unit % 2 == 0) 1 else -1).dp

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun LearnScreen(stats: TopStats, units: List<UnitUi>, onStart: (LessonSpec) -> Unit) {
    val palette = LocalPalette.current
    // Each unit takes a banner, its nodes, and a review node in the list.
    val banners = remember(units) { units.runningFold(0) { at, unit -> at + unit.nodes.size + 2 } }
    val list = rememberLazyListState(
        initialFirstVisibleItemIndex = remember {
            units.firstNotNullOfOrNull { unit ->
                // Land one row above the suggested node so the pinned banner does not sit on it.
                unit.nodes.indexOfFirst { it.current }.takeIf { it >= 0 }?.let { banners[unit.index] + it }
            } ?: 0
        },
    )
    var open by rememberSaveable { mutableStateOf<String?>(null) }
    var showUnits by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize().background(palette.background)) {
        StatsBar(stats)
        LazyColumn(
            state = list,
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(bottom = 40.dp),
        ) {
            units.forEach { unit ->
                stickyHeader(key = "unit:${unit.id}") {
                    UnitBanner(unit, onClick = { showUnits = true })
                }
                itemsIndexed(unit.nodes, key = { _, node -> node.skillId }) { step, node ->
                    val tone = if (node.state == NodeState.MASTERED) palette.gold else palette.unit(unit.index)
                    val offset = sway(unit.index, step)
                    PathRow(
                        offset = offset,
                        expanded = open == node.skillId,
                        card = {
                            NodeCard(
                                tone = tone,
                                caret = offset,
                                title = node.title,
                                detail = node.detail(),
                                action = node.action(),
                                onStart = {
                                    open = null
                                    onStart(LessonSpec.SkillLesson(node.skillId))
                                },
                            )
                        },
                        companion = if (step == 2) {
                            { Mascot(Modifier.size(88.dp), Mood.entries[unit.index % 2], palette.unit(unit.index)) }
                        } else {
                            null
                        },
                    ) {
                        SkillNode(
                            node = node,
                            tone = tone,
                            onClick = { open = if (open == node.skillId) null else node.skillId },
                        )
                    }
                }
                item(key = "review:${unit.id}") {
                    val key = "review:${unit.id}"
                    val tone = when {
                        unit.complete -> palette.gold
                        unit.started -> palette.unit(unit.index)
                        else -> palette.idle
                    }
                    val offset = sway(unit.index, unit.nodes.size)
                    PathRow(
                        offset = offset,
                        expanded = open == key,
                        card = {
                            NodeCard(
                                tone = if (unit.started) tone else palette.unit(unit.index),
                                caret = offset,
                                title = "Unit review",
                                detail = "A mix of questions from all of ${unit.title}.",
                                action = "Start",
                                onStart = {
                                    open = null
                                    onStart(LessonSpec.UnitReview(unit.id))
                                },
                            )
                        },
                        modifier = Modifier.padding(bottom = 20.dp),
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            NodeButton(
                                face = tone.face,
                                edge = tone.edge,
                                onClick = { open = if (open == key) null else key },
                            ) {
                                TrophyIcon(
                                    Modifier.size(38.dp),
                                    tint = if (unit.started) palette.onTone else palette.idleText,
                                )
                            }
                            NodeLabel("Unit review")
                        }
                    }
                }
            }
        }
    }

    if (showUnits) {
        ModalBottomSheet(
            onDismissRequest = { showUnits = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = palette.background,
        ) {
            UnitList(units) { unit ->
                showUnits = false
                open = null
                scope.launch { list.animateScrollToItem(banners[unit.index]) }
            }
        }
    }
}

private fun NodeUi.detail(): String = when (state) {
    NodeState.NOT_STARTED, NodeState.UP_NEXT -> "$total questions"
    NodeState.IN_PROGRESS -> "$learned of $total learned" + if (due > 0) " · $due due" else ""
    NodeState.COMPLETE ->
        if (due > 0) "All $total learned · $due due for review" else "All $total learned. Reviews keep it fresh."
    NodeState.MASTERED ->
        if (due > 0) "Mastered · $due due for review" else "Mastered. Recalled across weeks of reviews."
}

private fun NodeUi.action(): String = when (state) {
    NodeState.NOT_STARTED -> "Jump here"
    NodeState.UP_NEXT -> "Start"
    NodeState.IN_PROGRESS -> "Continue"
    NodeState.COMPLETE, NodeState.MASTERED -> if (due > 0) "Review" else "Practice"
}

@Composable
private fun StatsBar(stats: TopStats) {
    val palette = LocalPalette.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 20.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconLabel(
            icon = { FlameIcon(Modifier.size(28.dp), lit = stats.practicedToday) },
            text = "${stats.streak}",
            color = if (stats.practicedToday) palette.text else palette.textFaint,
        )
        IconLabel(
            icon = { BoltIcon(Modifier.size(26.dp)) },
            text = "${stats.totalXp} XP",
            color = palette.text,
        )
        IconLabel(
            icon = { GoalRing(stats.todayXp, stats.dailyGoal, Modifier.size(26.dp)) },
            text = "${stats.todayXp}/${stats.dailyGoal}",
            color = palette.text,
        )
    }
}

/** Today's XP against the daily goal. */
@Composable
fun GoalRing(xp: Int, goal: Int, modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    val reached = xp >= goal
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = size.minDimension * 0.2f
            val inset = Offset(stroke / 2, stroke / 2)
            val span = Size(size.width - stroke, size.height - stroke)
            if (reached) {
                drawCircle(palette.blue.face)
            } else {
                drawArc(palette.blue.face.copy(alpha = 0.22f), 0f, 360f, false, inset, span, style = Stroke(stroke))
                drawArc(
                    color = palette.blue.face,
                    startAngle = -90f,
                    sweepAngle = 360f * xp / goal.coerceAtLeast(1),
                    useCenter = false,
                    topLeft = inset,
                    size = span,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        if (reached) CheckIcon(Modifier.fillMaxSize().padding(5.dp), tint = palette.onTone)
    }
}

@Composable
private fun UnitBanner(unit: UnitUi, onClick: () -> Unit) {
    val palette = LocalPalette.current
    val tone = palette.unit(unit.index)
    Box(Modifier.fillMaxWidth().background(palette.background).padding(horizontal = 16.dp, vertical = 8.dp)) {
        Chunky(
            face = tone.face,
            edge = tone.edge,
            onClick = onClick,
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.CenterStart,
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("UNIT ${unit.index + 1}", style = Type.eyebrow, color = palette.onTone)
                    Text(unit.title, style = Type.heading, color = palette.onTone)
                    Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Meter(
                            progress = unit.learned.toFloat() / unit.total.coerceAtLeast(1),
                            color = palette.onTone,
                            track = palette.onTone.copy(alpha = 0.3f),
                            height = 8.dp,
                            gloss = false,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            "${unit.learned}/${unit.total}",
                            style = Type.eyebrow,
                            color = palette.onTone,
                            modifier = Modifier.padding(start = 10.dp),
                        )
                    }
                }
                MenuIcon(Modifier.padding(start = 14.dp).size(26.dp), tint = palette.onTone)
            }
        }
    }
}

/** One step of the path: a node pushed off the centre line, and the card that opens under it. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PathRow(
    offset: Dp,
    expanded: Boolean,
    card: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    companion: (@Composable () -> Unit)? = null,
    node: @Composable () -> Unit,
) {
    val bring = remember { BringIntoViewRequester() }
    LaunchedEffect(expanded) {
        if (expanded) {
            // Wait for the card to finish growing, or only its first sliver is scrolled into view.
            delay(220)
            bring.bringIntoView()
        }
    }
    Column(modifier.fillMaxWidth().padding(top = 6.dp)) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            if (companion != null) {
                Box(
                    Modifier
                        .align(if (offset > 0.dp) Alignment.CenterStart else Alignment.CenterEnd)
                        .padding(horizontal = 36.dp),
                ) { companion() }
            }
            Box(Modifier.offset(x = offset)) { node() }
        }
        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(tween(180)) + fadeIn(tween(180)),
            exit = shrinkVertically(tween(140)) + fadeOut(tween(100)),
            modifier = Modifier.bringIntoViewRequester(bring),
        ) { card() }
    }
}

@Composable
private fun SkillNode(node: NodeUi, tone: Tone, onClick: () -> Unit) {
    val palette = LocalPalette.current
    val idle = node.state == NodeState.NOT_STARTED
    val face = if (idle) palette.idle else tone
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        if (node.current) {
            StartBubble(
                text = if (node.state == NodeState.IN_PROGRESS) "Continue" else "Start",
                color = if (palette.dark) tone.face else tone.edge,
            )
        }
        NodeButton(
            face = face.face,
            edge = face.edge,
            onClick = onClick,
            ring = when {
                node.state == NodeState.IN_PROGRESS -> node.learned.toFloat() / node.total.coerceAtLeast(1)
                node.current -> 0f
                else -> null
            },
            ringColor = tone.face,
            badge = node.due.takeIf { it > 0 },
        ) {
            val tint = if (idle) palette.idleText else palette.onTone
            when (node.state) {
                NodeState.MASTERED -> CrownIcon(Modifier.size(38.dp), tint)
                NodeState.COMPLETE -> CheckIcon(Modifier.size(36.dp), tint)
                else -> StarIcon(Modifier.size(38.dp), tint)
            }
        }
        NodeLabel(node.title)
    }
}

@Composable
private fun NodeLabel(text: String) {
    Text(
        text,
        style = Type.small,
        color = LocalPalette.current.textSoft,
        textAlign = TextAlign.Center,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.widthIn(max = 150.dp),
    )
}

@Composable
private fun NodeButton(
    face: Color,
    edge: Color,
    onClick: () -> Unit,
    ring: Float? = null,
    ringColor: Color = face,
    badge: Int? = null,
    content: @Composable () -> Unit,
) {
    val palette = LocalPalette.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val sink by animateDpAsState(if (pressed) NodeLip else 0.dp, tween(60), label = "sink")
    Box(Modifier.size(92.dp), contentAlignment = Alignment.Center) {
        if (ring != null) {
            Canvas(Modifier.fillMaxSize()) {
                val stroke = 7.dp.toPx()
                val inset = Offset(stroke / 2, stroke / 2)
                val span = Size(size.width - stroke, size.height - stroke)
                drawArc(palette.border, 0f, 360f, false, inset, span, style = Stroke(stroke))
                if (ring > 0f) {
                    val round = Stroke(stroke, cap = StrokeCap.Round)
                    drawArc(ringColor, -90f, 360f * ring, false, inset, span, style = round)
                }
            }
        }
        Box(
            modifier = Modifier
                .size(width = 66.dp, height = 62.dp)
                .clickable(interaction, indication = null, role = Role.Button, onClick = onClick)
                .drawBehind {
                    val lip = NodeLip.toPx()
                    val oval = Size(size.width, size.height - lip)
                    drawOval(edge, Offset(0f, lip), oval)
                    drawOval(face, Offset(0f, sink.toPx()), oval)
                }
                .padding(bottom = NodeLip)
                .offset { IntOffset(0, sink.roundToPx()) },
            contentAlignment = Alignment.Center,
        ) { content() }
        if (badge != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 6.dp, end = 4.dp)
                    .size(26.dp)
                    .background(palette.background, CircleShape)
                    .padding(2.dp)
                    .background(palette.orange.face, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(if (badge > 9) "9+" else "$badge", style = Type.eyebrow, color = palette.onTone)
            }
        }
    }
}

/** The bobbing callout over the suggested node. */
@Composable
private fun StartBubble(text: String, color: Color) {
    val palette = LocalPalette.current
    val bob by rememberInfiniteTransition(label = "bob").animateFloat(
        initialValue = 0f,
        targetValue = -6f,
        animationSpec = infiniteRepeatable(tween(700, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "bob",
    )
    Text(
        text.uppercase(),
        style = Type.label,
        color = color,
        modifier = Modifier
            .graphicsLayer { translationY = bob.dp.toPx() }
            .drawBehind {
                val line = 2.dp.toPx()
                val tail = 8.dp.toPx()
                val body = Size(size.width, size.height - tail)
                val corner = CornerRadius(12.dp.toPx())
                drawRoundRect(palette.border, size = body, cornerRadius = corner)
                drawRoundRect(
                    color = palette.background,
                    topLeft = Offset(line, line),
                    size = Size(body.width - 2 * line, body.height - 2 * line),
                    cornerRadius = CornerRadius(10.dp.toPx()),
                )
                val middle = size.width / 2
                val tip = Path().apply {
                    moveTo(middle - tail, body.height - line)
                    lineTo(middle, body.height + tail - line)
                    lineTo(middle + tail, body.height - line)
                }
                drawPath(tip, palette.background)
                drawPath(tip, palette.border, style = Stroke(line, cap = StrokeCap.Round))
            }
            .padding(start = 14.dp, end = 14.dp, top = 9.dp, bottom = 17.dp),
    )
}

/** What opens under a tapped node: what it is, where it stands, and the button that starts it. */
@Composable
private fun NodeCard(
    tone: Tone,
    caret: Dp,
    title: String,
    detail: String,
    action: String,
    onStart: () -> Unit,
) {
    val palette = LocalPalette.current
    Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 6.dp)) {
        Canvas(Modifier.fillMaxWidth().height(10.dp)) {
            val middle = size.width / 2 + caret.toPx()
            val half = 11.dp.toPx()
            drawPath(
                Path().apply {
                    moveTo(middle - half, size.height)
                    lineTo(middle, 0f)
                    lineTo(middle + half, size.height)
                    close()
                },
                tone.face,
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(tone.face, RoundedCornerShape(16.dp))
                .padding(16.dp),
        ) {
            Text(title, style = Type.heading, color = palette.onTone)
            Text(detail, style = Type.body, color = palette.onTone, modifier = Modifier.padding(top = 2.dp))
            Spacer(Modifier.height(14.dp))
            Chunky(
                face = if (palette.dark) palette.background else Color.White,
                edge = Color.Black.copy(alpha = 0.2f),
                onClick = onStart,
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) {
                Text(action.uppercase(), style = Type.label, color = if (palette.dark) tone.face else tone.edge)
            }
        }
    }
}

@Composable
private fun UnitList(units: List<UnitUi>, onPick: (UnitUi) -> Unit) {
    val palette = LocalPalette.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .navigationBarsPadding()
            .padding(start = 20.dp, end = 20.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionTitle("Units", Modifier.padding(bottom = 4.dp))
        units.forEach { unit ->
            val tone = palette.unit(unit.index)
            Chunky(
                face = palette.background,
                edge = palette.border,
                border = 2.dp,
                lip = 2.dp,
                onClick = { onPick(unit) },
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.CenterStart,
            ) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier.size(44.dp).background(tone.face, RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("${unit.index + 1}", style = Type.heading, color = palette.onTone)
                    }
                    Column(Modifier.padding(start = 12.dp).weight(1f)) {
                        Text(unit.title, style = Type.bodyStrong, color = palette.text)
                        Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Meter(
                                progress = unit.learned.toFloat() / unit.total.coerceAtLeast(1),
                                color = tone.face,
                                height = 10.dp,
                                gloss = false,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                "${unit.learned}/${unit.total}",
                                style = Type.eyebrow,
                                color = palette.textSoft,
                                modifier = Modifier.padding(start = 10.dp).width(52.dp),
                                textAlign = TextAlign.End,
                            )
                        }
                    }
                }
            }
        }
    }
}
