package com.marchein.whateverscanner.ui.screens

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marchein.whateverscanner.models.AppSettingsData
import com.marchein.whateverscanner.models.SettingsRepository
import com.marchein.whateverscanner.models.WebDAVServer
import com.marchein.whateverscanner.services.WebDAVService
import com.marchein.whateverscanner.services.localizedMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Result of a connection test, surfaced to the UI as a snackbar/dialog. */
sealed interface ConnectionTestResult {
    data object Success : ConnectionTestResult
    data class Failure(val message: String) : ConnectionTestResult
}

@HiltViewModel
class AddServerViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val webDavService: WebDAVService
) : ViewModel() {

    private val _isTesting = MutableStateFlow(false)
    val isTesting: StateFlow<Boolean> = _isTesting.asStateFlow()

    private val _testResult = MutableStateFlow<ConnectionTestResult?>(null)
    val testResult: StateFlow<ConnectionTestResult?> = _testResult.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    /** Loads an existing server (with password) by id, or null when adding. */
    suspend fun loadServer(serverId: String?): WebDAVServer? {
        if (serverId == null) return null
        val current: AppSettingsData = settingsRepository.settings.first()
        return current.servers.firstOrNull { it.id == serverId }
    }

    fun testConnection(server: WebDAVServer) {
        viewModelScope.launch {
            _isTesting.value = true
            _testResult.value = try {
                webDavService.testConnection(server)
                ConnectionTestResult.Success
            } catch (e: Exception) {
                ConnectionTestResult.Failure(e.localizedMessage(context))
            } finally {
                _isTesting.value = false
            }
        }
    }

    fun clearTestResult() {
        _testResult.value = null
    }

    /** Saves the server (add or update) and invokes [onSaved] on completion. */
    fun save(server: WebDAVServer, isEditing: Boolean, onSaved: () -> Unit) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                if (isEditing) {
                    settingsRepository.updateServer(server)
                } else {
                    settingsRepository.addServer(server)
                }
                onSaved()
            } finally {
                _isSaving.value = false
            }
        }
    }
}
