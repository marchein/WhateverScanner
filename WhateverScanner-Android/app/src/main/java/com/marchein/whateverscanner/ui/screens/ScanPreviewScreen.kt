package com.marchein.whateverscanner.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.selection.selectable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.marchein.whateverscanner.R
import com.marchein.whateverscanner.ui.components.PDFViewer
import com.marchein.whateverscanner.util.buildUploadFilename
import com.marchein.whateverscanner.util.formatDisplayDate
import kotlinx.coroutines.launch
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanPreviewScreen(
    viewModel: MainViewModel,
    onDone: () -> Unit
) {
    val preview by viewModel.previewState.collectAsStateWithLifecycle()
    val state = preview ?: run {
        LaunchedEffect(Unit) { onDone() }
        return
    }

    val scope = rememberCoroutineScope()
    var documentName by remember(state) { mutableStateOf(state.suggestedName ?: "") }
    var useDocumentDate by remember(state) { mutableStateOf(state.documentDate != null) }
    val selectedDate: Date = if (useDocumentDate) state.documentDate ?: state.scanDate else state.scanDate

    var showEditSheet by remember { mutableStateOf(false) }
    var isUploading by remember { mutableStateOf(false) }
    var uploadResult by remember { mutableStateOf<UploadOutcome?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.scan_preview)) },
                actions = {
                    if (isUploading) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .padding(end = 16.dp)
                                .size(24.dp),
                            strokeWidth = 2.dp
                        )
                    } else {
                        IconButton(onClick = {
                            scope.launch {
                                isUploading = true
                                val filename = buildUploadFilename(documentName, selectedDate)
                                uploadResult = viewModel.upload(state.pdfData, filename)
                                isUploading = false
                            }
                        }) {
                            Icon(
                                imageVector = Icons.Outlined.CloudUpload,
                                contentDescription = stringResource(R.string.upload)
                            )
                        }
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(modifier = Modifier
            .fillMaxSize()
            .padding(innerPadding)) {

            DocumentInfoBar(
                name = documentName.ifBlank { stringResource(R.string.document_name) },
                date = formatDisplayDate(selectedDate),
                onEdit = { showEditSheet = true }
            )

            PDFViewer(
                pdfData = state.pdfData,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            )
        }
    }

    if (showEditSheet) {
        EditDetailsDialog(
            name = documentName,
            onNameChange = { documentName = it },
            scanDate = state.scanDate,
            documentDate = state.documentDate,
            useDocumentDate = useDocumentDate,
            onUseDocumentDateChange = { useDocumentDate = it },
            onDismiss = { showEditSheet = false }
        )
    }

    uploadResult?.let { result ->
        UploadResultDialog(
            result = result,
            onDismiss = {
                val success = result.isCompleteSuccess
                uploadResult = null
                if (success) {
                    viewModel.clearPreview()
                    onDone()
                }
            }
        )
    }
}

@Composable
private fun DocumentInfoBar(name: String, date: String, onEdit: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.size(2.dp))
                Text(
                    text = date,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.edit_details))
            }
        }
    }
}

@Composable
private fun EditDetailsDialog(
    name: String,
    onNameChange: (String) -> Unit,
    scanDate: Date,
    documentDate: Date?,
    useDocumentDate: Boolean,
    onUseDocumentDateChange: (Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.edit_details)) },
        text = {
            Column {
                OutlinedTextField(
                    value = name,
                    onValueChange = onNameChange,
                    label = { Text(stringResource(R.string.document_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.size(16.dp))
                Text(
                    text = stringResource(R.string.date),
                    style = MaterialTheme.typography.labelLarge
                )
                DateOption(
                    label = stringResource(R.string.scan_date),
                    subtitle = formatDisplayDate(scanDate),
                    selected = !useDocumentDate,
                    onSelect = { onUseDocumentDateChange(false) }
                )
                if (documentDate != null) {
                    DateOption(
                        label = stringResource(R.string.document_date),
                        subtitle = formatDisplayDate(documentDate),
                        selected = useDocumentDate,
                        onSelect = { onUseDocumentDateChange(true) }
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.done)) }
        }
    )
}

@Composable
private fun DateOption(
    label: String,
    subtitle: String,
    selected: Boolean,
    onSelect: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = selected, onClick = onSelect)
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RadioButton(selected = selected, onClick = onSelect)
        Spacer(Modifier.size(8.dp))
        Column {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun UploadResultDialog(result: UploadOutcome, onDismiss: () -> Unit) {
    val title: String
    val message: String
    when {
        result.isCompleteSuccess -> {
            title = stringResource(R.string.upload_successful)
            message = pluralStringResource(
                R.plurals.document_uploaded,
                result.successCount,
                result.successCount
            )
        }

        result.isCompleteFailure -> {
            title = stringResource(R.string.upload_failed)
            message = stringResource(R.string.upload_failed_prefix) + "\n" +
                result.failures.joinToString("\n")
        }

        else -> {
            title = stringResource(R.string.upload_failed)
            message = pluralStringResource(
                R.plurals.uploaded_partial,
                result.successCount,
                result.successCount
            ) + "\n" + result.failures.joinToString("\n")
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.ok)) }
        }
    )
}
