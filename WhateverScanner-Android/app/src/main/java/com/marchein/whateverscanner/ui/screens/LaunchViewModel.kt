package com.marchein.whateverscanner.ui.screens

import androidx.lifecycle.ViewModel
import com.marchein.whateverscanner.models.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import javax.inject.Inject

@HiltViewModel
class LaunchViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {
    /** Suspends until the persisted settings are loaded, returning the setup flag. */
    suspend fun isSetupComplete(): Boolean = settingsRepository.settings.first().isSetupComplete
}
