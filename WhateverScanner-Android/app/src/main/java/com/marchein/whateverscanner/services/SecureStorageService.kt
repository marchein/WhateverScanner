package com.marchein.whateverscanner.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure storage for WebDAV passwords, backed by [EncryptedSharedPreferences]
 * and an Android Keystore master key.
 *
 * This is the Android equivalent of the iOS `KeychainService`: passwords never
 * touch DataStore or plain SharedPreferences and are encrypted at rest with a
 * device-bound key.
 */
@Singleton
class SecureStorageService @Inject constructor(
    @ApplicationContext context: Context
) {
    private val prefs: SharedPreferences by lazy { createEncryptedPrefs(context) }

    private fun createEncryptedPrefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /** Stores (or updates) the password for the given server key. */
    fun savePassword(key: String, password: String) {
        prefs.edit().putString(key, password).apply()
    }

    /** Retrieves the password for the given server key, or null if none is stored. */
    fun retrievePassword(key: String): String? = prefs.getString(key, null)

    /** Removes the stored password for the given server key. */
    fun deletePassword(key: String) {
        prefs.edit().remove(key).apply()
    }

    companion object {
        const val PREFS_NAME = "whateverscanner_secure_prefs"
    }
}
