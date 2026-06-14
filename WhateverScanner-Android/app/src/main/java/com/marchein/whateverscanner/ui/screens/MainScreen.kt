package com.marchein.whateverscanner.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.marchein.whateverscanner.R
import com.marchein.whateverscanner.ui.components.rememberDocumentScanner
import kotlinx.coroutines.launch

/**
 * Primary scanner home screen: shows the upload destination and a large button
 * to start a document scan.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    viewModel: MainViewModel,
    onOpenSettings: () -> Unit,
    onScanReady: () -> Unit
) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val isAnalyzing by viewModel.isAnalyzing.collectAsStateWithLifecycle()
    val scanError by viewModel.scanError.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    val scanner = rememberDocumentScanner(
        onScanned = { uris ->
            scope.launch {
                val produced = viewModel.processScan(uris)
                if (produced) onScanReady()
            }
        },
        onCancelled = { },
        onError = { e -> viewModel.reportScanError(e.localizedMessage) }
    )

    // Auto-start the scanner on launch when enabled and at least one server exists.
    LaunchedEffect(settings.autoStartScan, settings.isSetupComplete) {
        if (settings.autoStartScan && settings.servers.isNotEmpty()) {
            scanner()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(
                            imageVector = Icons.Outlined.Settings,
                            contentDescription = stringResource(R.string.settings)
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(32.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.DocumentScanner,
                    contentDescription = null,
                    modifier = Modifier.size(72.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.ready_to_scan),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(8.dp))
                UploadDestinationLabel(
                    uploadToAll = settings.uploadToAllServers,
                    serverCount = settings.servers.size,
                    defaultServerName = settings.defaultServer?.name
                )
                Spacer(Modifier.height(40.dp))
                Button(
                    onClick = { scanner() },
                    enabled = !isAnalyzing,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (isAnalyzing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = MaterialTheme.colorScheme.onPrimary,
                            strokeWidth = 2.dp
                        )
                        Spacer(Modifier.size(8.dp))
                        Text(stringResource(R.string.analyzing))
                    } else {
                        Icon(Icons.Filled.DocumentScanner, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text(stringResource(R.string.scan_document))
                    }
                }
            }
        }
    }

    scanError?.let { error ->
        val message = when (error) {
            MainViewModel.ScanErrorKind.PDF.name -> stringResource(R.string.failed_to_create_pdf)
            MainViewModel.ScanErrorKind.GENERIC.name -> stringResource(R.string.scan_error)
            else -> stringResource(R.string.scan_failed, error)
        }
        AlertDialog(
            onDismissRequest = { viewModel.clearScanError() },
            title = { Text(stringResource(R.string.scan_error)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { viewModel.clearScanError() }) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }
}

@Composable
private fun UploadDestinationLabel(
    uploadToAll: Boolean,
    serverCount: Int,
    defaultServerName: String?
) {
    val text = if (uploadToAll) {
        stringResource(R.string.uploading_to_all, serverCount)
    } else {
        stringResource(R.string.uploading_to, defaultServerName ?: "—")
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            imageVector = Icons.Outlined.CloudUpload,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
