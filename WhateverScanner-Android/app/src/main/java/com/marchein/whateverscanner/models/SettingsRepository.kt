package com.marchein.whateverscanner.models

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.marchein.whateverscanner.services.SecureStorageService
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore(name = "whateverscanner_settings")

/**
 * Repository managing app-wide configuration.
 *
 * Non-sensitive settings are persisted with Jetpack DataStore (the Android
 * equivalent of `UserDefaults`). Server passwords are stored separately in
 * [SecureStorageService]; the JSON written to DataStore contains metadata only.
 */
@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val secureStorage: SecureStorageService
) {
    private object Keys {
        val SETUP_COMPLETE = booleanPreferencesKey("setup_complete")
        val AUTO_START_SCAN = booleanPreferencesKey("auto_start_scan")
        val UPLOAD_TO_ALL = booleanPreferencesKey("upload_to_all_servers")
        val DEFAULT_SERVER_ID = stringPreferencesKey("default_server_id")
        val SERVERS_JSON = stringPreferencesKey("servers_json")
    }

    /** Reactive stream of the full settings state, with passwords re-attached. */
    val settings: Flow<AppSettingsData> = context.dataStore.data.map { prefs ->
        val servers = parseServers(prefs[Keys.SERVERS_JSON]).map { server ->
            server.copy(password = secureStorage.retrievePassword(server.id) ?: "")
        }
        AppSettingsData(
            isSetupComplete = prefs[Keys.SETUP_COMPLETE] ?: false,
            autoStartScan = prefs[Keys.AUTO_START_SCAN] ?: false,
            uploadToAllServers = prefs[Keys.UPLOAD_TO_ALL] ?: false,
            defaultServerId = prefs[Keys.DEFAULT_SERVER_ID],
            servers = servers
        )
    }

    suspend fun setAutoStartScan(enabled: Boolean) {
        context.dataStore.edit { it[Keys.AUTO_START_SCAN] = enabled }
    }

    suspend fun setUploadToAllServers(enabled: Boolean) {
        context.dataStore.edit { it[Keys.UPLOAD_TO_ALL] = enabled }
    }

    suspend fun setDefaultServer(serverId: String) {
        context.dataStore.edit { it[Keys.DEFAULT_SERVER_ID] = serverId }
    }

    /** Adds a new server, storing its password securely. */
    suspend fun addServer(server: WebDAVServer) {
        secureStorage.savePassword(server.id, server.password)
        context.dataStore.edit { prefs ->
            val current = parseServers(prefs[Keys.SERVERS_JSON]).toMutableList()
            current.add(server)
            prefs[Keys.SERVERS_JSON] = serializeServers(current)
            if (prefs[Keys.DEFAULT_SERVER_ID] == null) {
                prefs[Keys.DEFAULT_SERVER_ID] = server.id
            }
        }
    }

    /** Updates an existing server's metadata and password. */
    suspend fun updateServer(server: WebDAVServer) {
        secureStorage.savePassword(server.id, server.password)
        context.dataStore.edit { prefs ->
            val current = parseServers(prefs[Keys.SERVERS_JSON]).toMutableList()
            val index = current.indexOfFirst { it.id == server.id }
            if (index >= 0) {
                current[index] = server
            } else {
                current.add(server)
            }
            prefs[Keys.SERVERS_JSON] = serializeServers(current)
        }
    }

    /** Removes a server and its stored password, reassigning the default if needed. */
    suspend fun removeServer(serverId: String) {
        secureStorage.deletePassword(serverId)
        context.dataStore.edit { prefs ->
            val current = parseServers(prefs[Keys.SERVERS_JSON]).toMutableList()
            current.removeAll { it.id == serverId }
            prefs[Keys.SERVERS_JSON] = serializeServers(current)
            if (prefs[Keys.DEFAULT_SERVER_ID] == serverId) {
                val next = current.firstOrNull()?.id
                if (next != null) {
                    prefs[Keys.DEFAULT_SERVER_ID] = next
                } else {
                    prefs.remove(Keys.DEFAULT_SERVER_ID)
                }
            }
        }
    }

    /** Marks initial onboarding as complete. */
    suspend fun completeSetup() {
        context.dataStore.edit { it[Keys.SETUP_COMPLETE] = true }
    }

    private fun parseServers(json: String?): List<WebDAVServer> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { WebDAVServer.fromJson(array.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun serializeServers(servers: List<WebDAVServer>): String {
        val array = JSONArray()
        servers.forEach { array.put(it.toJson()) }
        return array.toString()
    }
}
