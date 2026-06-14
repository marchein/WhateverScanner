package com.marchein.whateverscanner.models

import org.json.JSONObject
import java.util.UUID

/**
 * Represents a single WebDAV server configuration.
 *
 * The [password] is **never** serialized to JSON or DataStore — it is stored
 * separately in [com.marchein.whateverscanner.services.SecureStorageService]
 * (EncryptedSharedPreferences) and re-attached at runtime, mirroring the iOS
 * app's Keychain-backed design.
 */
data class WebDAVServer(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val url: String,
    val username: String,
    val password: String = ""
) {
    /** Serializes metadata only (id, name, url, username) — never the password. */
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("url", url)
        put("username", username)
    }

    companion object {
        /** Restores a server from its metadata JSON. The password defaults to empty. */
        fun fromJson(json: JSONObject): WebDAVServer = WebDAVServer(
            id = json.optString("id", UUID.randomUUID().toString()),
            name = json.optString("name"),
            url = json.optString("url"),
            username = json.optString("username"),
            password = ""
        )
    }
}
