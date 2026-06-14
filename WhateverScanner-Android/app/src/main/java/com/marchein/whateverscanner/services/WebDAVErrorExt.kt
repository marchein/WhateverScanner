package com.marchein.whateverscanner.services

import android.content.Context
import com.marchein.whateverscanner.R

/**
 * Maps an exception (typically a [WebDAVError]) to a user-facing, localized
 * message. Falls back to the throwable's own message for unexpected errors.
 */
fun Throwable.localizedMessage(context: Context): String = when (this) {
    is WebDAVError.InvalidUrl -> context.getString(R.string.error_invalid_url)
    is WebDAVError.AuthenticationFailed -> context.getString(R.string.error_authentication_failed)
    is WebDAVError.ServerError -> context.getString(R.string.error_server_code, code)
    is WebDAVError.NetworkError -> cause.localizedMessage ?: context.getString(R.string.error)
    else -> message ?: context.getString(R.string.error)
}
