package com.marchein.whateverscanner.util

import android.util.Patterns
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Trims whitespace and ensures the URL ends with a single trailing slash. */
fun normalizeServerUrl(url: String): String {
    val trimmed = url.trim()
    if (trimmed.isEmpty()) return trimmed
    return if (trimmed.endsWith("/")) trimmed else "$trimmed/"
}

/** Returns true if the URL is a syntactically valid web URL. */
fun isValidUrl(url: String): Boolean {
    val trimmed = url.trim()
    return trimmed.isNotEmpty() && Patterns.WEB_URL.matcher(trimmed).matches()
}

/** Characters that are illegal in filenames on common WebDAV backends. */
private val INVALID_FILENAME_CHARS = charArrayOf('/', '\\', ':', '*', '?', '"', '<', '>', '|')

/** Replaces invalid filename characters with underscores. */
fun sanitizeFilename(name: String): String {
    var sanitized = name.trim()
    for (c in INVALID_FILENAME_CHARS) {
        sanitized = sanitized.replace(c, '_')
    }
    return sanitized
}

/**
 * Builds the destination filename for an upload.
 *
 * Format: `{SanitizedName}_{yyyy-MM-dd_HH-mm-ss}.pdf`, matching the iOS app.
 * Falls back to `Scan` when [name] is blank.
 */
fun buildUploadFilename(name: String, date: Date): String {
    val base = sanitizeFilename(name).ifBlank { "Scan" }
    val formatter = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US)
    return "${base}_${formatter.format(date)}.pdf"
}

/** Formats a date for display in the preview UI. */
fun formatDisplayDate(date: Date): String {
    val formatter = SimpleDateFormat("dd.MM.yyyy", Locale.getDefault())
    return formatter.format(date)
}
