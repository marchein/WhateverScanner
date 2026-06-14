package com.marchein.whateverscanner.models

/**
 * Immutable snapshot of all app settings, exposed reactively to the UI.
 */
data class AppSettingsData(
    val isSetupComplete: Boolean = false,
    val autoStartScan: Boolean = false,
    val uploadToAllServers: Boolean = false,
    val defaultServerId: String? = null,
    val servers: List<WebDAVServer> = emptyList()
) {
    /** The currently selected default server, or the first available server. */
    val defaultServer: WebDAVServer?
        get() = servers.firstOrNull { it.id == defaultServerId } ?: servers.firstOrNull()

    /**
     * The list of servers a scan should be uploaded to, based on the
     * [uploadToAllServers] preference.
     */
    val uploadTargets: List<WebDAVServer>
        get() = if (uploadToAllServers) servers else listOfNotNull(defaultServer)
}
