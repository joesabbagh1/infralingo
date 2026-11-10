package com.infralingo.ui

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.io.IOException

private enum class Tab(val label: String) {
    LEARN("Learn"),
    PRACTICE("Practice"),
    PROFILE("Profile"),
}

@Composable
fun InfralingoApp(viewModel: InfralingoViewModel) {
    val lesson by viewModel.lesson.collectAsStateWithLifecycle()
    val notice by viewModel.notice.collectAsStateWithLifecycle()
    val context = LocalContext.current
    // Lives above the lesson so coming back lands on the tab the lesson was started from.
    var tab by rememberSaveable { mutableStateOf(Tab.LEARN) }

    LaunchedEffect(notice) {
        val message = notice ?: return@LaunchedEffect
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        viewModel.consumeNotice()
    }
    LifecycleResumeEffect(viewModel) {
        viewModel.refresh()
        onPauseOrDispose { }
    }

    AnimatedContent(
        targetState = lesson,
        contentKey = { it != null },
        transitionSpec = {
            if (targetState != null) {
                slideInVertically(tween(260)) { it / 6 } + fadeIn(tween(200)) togetherWith fadeOut(tween(120))
            } else {
                fadeIn(tween(200)) togetherWith slideOutVertically(tween(200)) { it / 6 } + fadeOut(tween(160))
            }
        },
        modifier = Modifier.fillMaxSize().background(LocalPalette.current.background),
        label = "screen",
    ) { shown ->
        if (shown == null) {
            MainTabs(viewModel, tab, onTab = { tab = it })
        } else {
            LessonScreen(
                ui = shown,
                onSelect = viewModel::select,
                onHint = viewModel::hint,
                onCheck = viewModel::check,
                onNext = viewModel::next,
                onClose = viewModel::close,
            )
        }
    }
}

@Composable
private fun MainTabs(viewModel: InfralingoViewModel, tab: Tab, onTab: (Tab) -> Unit) {
    val app by viewModel.app.collectAsStateWithLifecycle()
    val palette = LocalPalette.current
    val error = app.error
    when {
        app.loading -> Notice(Mood.HAPPY, "Loading your path…")
        error != null -> Notice(Mood.OOPS, error)
        else -> Column(Modifier.fillMaxSize().background(palette.background)) {
            Box(Modifier.weight(1f)) {
                when (tab) {
                    Tab.LEARN -> LearnScreen(app.stats, app.units, viewModel::start)
                    Tab.PRACTICE -> PracticeScreen(app.practice, viewModel::start)
                    Tab.PROFILE -> ProfileRoute(app, viewModel)
                }
            }
            TabBar(tab, onTab)
        }
    }
}

@Composable
private fun Notice(mood: Mood, text: String) {
    val palette = LocalPalette.current
    Column(
        modifier = Modifier.fillMaxSize().background(palette.background).padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Mascot(Modifier.size(120.dp), mood)
        Text(
            text,
            style = Type.heading,
            color = palette.textSoft,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp),
        )
    }
}

@Composable
private fun TabBar(selected: Tab, onTab: (Tab) -> Unit) {
    val palette = LocalPalette.current
    Column(Modifier.fillMaxWidth().background(palette.background)) {
        Box(Modifier.fillMaxWidth().height(2.dp).background(palette.border))
        Row(Modifier.navigationBarsPadding().padding(vertical = 8.dp)) {
            Tab.entries.forEach { tab ->
                val active = tab == selected
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            role = Role.Tab,
                            onClick = { onTab(tab) },
                        ),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    val frame = if (active) {
                        Modifier
                            .background(palette.selectedTint, RoundedCornerShape(12.dp))
                            .border(2.dp, palette.selectedBorder, RoundedCornerShape(12.dp))
                    } else {
                        Modifier
                    }
                    Box(Modifier.size(width = 56.dp, height = 44.dp).then(frame), contentAlignment = Alignment.Center) {
                        when (tab) {
                            Tab.LEARN -> HomeIcon(Modifier.size(30.dp), tint = palette.orange.face)
                            Tab.PRACTICE -> DumbbellIcon(Modifier.size(32.dp), tint = palette.blue.face)
                            Tab.PROFILE -> PersonIcon(Modifier.size(30.dp), tint = palette.unit(1).face)
                        }
                    }
                    Text(
                        tab.label.uppercase(),
                        style = Type.eyebrow,
                        color = if (active) palette.selectedInk else palette.textSoft,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfileRoute(app: AppUi, viewModel: InfralingoViewModel) {
    val context = LocalContext.current
    var pendingImport by remember { mutableStateOf<String?>(null) }

    val saveAs = ActivityResultContracts.CreateDocument("application/json")
    val exporter = rememberLauncherForActivityResult(saveAs) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        try {
            context.contentResolver.openOutputStream(uri)?.use { it.write(viewModel.exportJson().toByteArray()) }
            viewModel.notify("Backup saved.")
        } catch (_: IOException) {
            viewModel.notify("Could not write the backup there.")
        }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = try {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        } catch (_: IOException) {
            null
        }
        if (text.isNullOrBlank()) viewModel.notify("That file could not be read.") else pendingImport = text
    }

    ProfileScreen(
        stats = app.stats,
        units = app.units,
        profile = app.profile,
        onGoal = viewModel::setDailyGoal,
        onExport = { exporter.launch("infralingo-progress.json") },
        onImport = { importer.launch(arrayOf("application/json", "text/plain")) },
    )

    pendingImport?.let { raw ->
        ReplaceProgressSheet(
            onReplace = {
                viewModel.importJson(raw)
                pendingImport = null
            },
            onCancel = { pendingImport = null },
        )
    }
}
