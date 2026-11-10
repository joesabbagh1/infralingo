package com.infralingo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import com.infralingo.ui.InfralingoApp
import com.infralingo.ui.InfralingoTheme
import com.infralingo.ui.InfralingoViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as InfralingoApplication
        setContent {
            InfralingoTheme {
                val viewModel: InfralingoViewModel = viewModel(factory = InfralingoViewModel.factory(app))
                InfralingoApp(viewModel)
            }
        }
    }
}
