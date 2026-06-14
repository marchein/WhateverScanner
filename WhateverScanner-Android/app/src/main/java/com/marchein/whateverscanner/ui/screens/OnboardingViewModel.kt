package com.marchein.whateverscanner.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marchein.whateverscanner.models.SettingsRepository
import com.marchein.whateverscanner.models.WebDAVServer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    /** Saves the first server and marks onboarding complete, then calls [onDone]. */
    fun completeOnboarding(server: WebDAVServer, onDone: () -> Unit) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                settingsRepository.addServer(server)
                settingsRepository.completeSetup()
                onDone()
            } finally {
                _isSaving.value = false
            }
        }
    }
}
