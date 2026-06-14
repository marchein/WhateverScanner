package com.marchein.whateverscanner.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marchein.whateverscanner.models.AppSettingsData
import com.marchein.whateverscanner.models.SettingsRepository
import com.marchein.whateverscanner.models.WebDAVServer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    val settings: StateFlow<AppSettingsData> = settingsRepository.settings.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = AppSettingsData()
    )

    fun setAutoStartScan(enabled: Boolean) = viewModelScope.launch {
        settingsRepository.setAutoStartScan(enabled)
    }

    fun setUploadToAllServers(enabled: Boolean) = viewModelScope.launch {
        settingsRepository.setUploadToAllServers(enabled)
    }

    fun setDefaultServer(serverId: String) = viewModelScope.launch {
        settingsRepository.setDefaultServer(serverId)
    }

    fun removeServer(server: WebDAVServer) = viewModelScope.launch {
        settingsRepository.removeServer(server.id)
    }
}
