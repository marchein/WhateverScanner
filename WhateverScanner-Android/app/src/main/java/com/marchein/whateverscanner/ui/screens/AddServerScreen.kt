package com.marchein.whateverscanner.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.marchein.whateverscanner.R
import com.marchein.whateverscanner.models.WebDAVServer
import com.marchein.whateverscanner.util.isValidUrl
import com.marchein.whateverscanner.util.normalizeServerUrl

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddServerScreen(
    serverId: String?,
    onBack: () -> Unit,
    viewModel: AddServerViewModel = hiltViewModel()
) {
    val isEditing = serverId != null
    var loadedId by remember { mutableStateOf<String?>(null) }
    var name by remember { mutableStateOf("") }
    var url by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    // Pre-fill the form when editing an existing server.
    LaunchedEffect(serverId) {
        val server = viewModel.loadServer(serverId)
        if (server != null) {
            loadedId = server.id
            name = server.name
            url = server.url
            username = server.username
            password = server.password
        }
    }

    val isTesting by viewModel.isTesting.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()
    val testResult by viewModel.testResult.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    val successMessage = stringResource(R.string.connection_success_message)
    LaunchedEffect(testResult) {
        when (val result = testResult) {
            is ConnectionTestResult.Success -> snackbarHostState.showSnackbar(successMessage)
            is ConnectionTestResult.Failure -> snackbarHostState.showSnackbar(result.message)
            null -> {}
        }
        if (testResult != null) viewModel.clearTestResult()
    }

    val isFormValid = name.isNotBlank() && url.isNotBlank() &&
        username.isNotBlank() && password.isNotBlank() && isValidUrl(url)

    fun currentServer() = WebDAVServer(
        id = loadedId ?: WebDAVServer(name = "", url = "", username = "").id,
        name = name.trim(),
        url = normalizeServerUrl(url),
        username = username.trim(),
        password = password
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(
                            if (isEditing) R.string.edit_server else R.string.add_server
                        )
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.cancel)
                        )
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            viewModel.save(currentServer(), isEditing, onBack)
                        },
                        enabled = isFormValid && !isSaving
                    ) {
                        Text(stringResource(R.string.save))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = stringResource(R.string.server_details),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text(stringResource(R.string.name)) },
                placeholder = { Text(stringResource(R.string.server_name_placeholder)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = url,
                onValueChange = { url = it },
                label = { Text(stringResource(R.string.url)) },
                placeholder = { Text(stringResource(R.string.server_url_placeholder)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text(stringResource(R.string.username)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text(stringResource(R.string.password)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.size(8.dp))

            OutlinedButton(
                onClick = { viewModel.testConnection(currentServer()) },
                enabled = isFormValid && !isTesting,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (isTesting) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.size(8.dp))
                    Text(stringResource(R.string.testing))
                } else {
                    Text(stringResource(R.string.test_connection))
                }
            }

            Spacer(Modifier.size(8.dp))

            Button(
                onClick = { viewModel.save(currentServer(), isEditing, onBack) },
                enabled = isFormValid && !isSaving,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(stringResource(R.string.save))
                }
            }
        }
    }
}
