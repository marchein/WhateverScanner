package com.marchein.whateverscanner.services

import com.marchein.whateverscanner.models.WebDAVServer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Credentials
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/** Errors that can occur during WebDAV operations. */
sealed class WebDAVError : Exception() {
    /** The server URL could not be parsed. */
    data object InvalidUrl : WebDAVError()

    /** The server rejected the provided credentials (HTTP 401). */
    data object AuthenticationFailed : WebDAVError()

    /** The server responded with an unexpected HTTP status code. */
    data class ServerError(val code: Int) : WebDAVError()

    /** A network-level error occurred. */
    data class NetworkError(override val cause: Throwable) : WebDAVError()
}

/**
 * Handles communication with WebDAV servers: file uploads via HTTP PUT and
 * connection testing via PROPFIND, using HTTP Basic authentication.
 *
 * Mirrors the iOS `WebDAVService` actor, including its timeouts and the set of
 * status codes treated as success (200–299 and 207 Multi-Status).
 */
@Singleton
class WebDAVService @Inject constructor() {

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build()

    /**
     * Uploads PDF [data] to [server] under [filename] using HTTP PUT.
     *
     * @throws WebDAVError on invalid URL, authentication failure, server error
     *   or network failure.
     */
    @Throws(WebDAVError::class)
    suspend fun upload(data: ByteArray, filename: String, server: WebDAVServer) {
        val urlString = server.url + filename
        val request = Request.Builder()
            .url(parseUrl(urlString))
            .header("Authorization", Credentials.basic(server.username, server.password))
            .put(data.toRequestBody(PDF_MEDIA_TYPE))
            .build()
        execute(request)
    }

    /**
     * Tests connectivity and authentication against [server] using a PROPFIND
     * request with `Depth: 0`.
     */
    @Throws(WebDAVError::class)
    suspend fun testConnection(server: WebDAVServer) {
        val request = Request.Builder()
            .url(parseUrl(server.url))
            .header("Authorization", Credentials.basic(server.username, server.password))
            .header("Depth", "0")
            .method("PROPFIND", null)
            .build()
        execute(request)
    }

    private fun parseUrl(value: String): HttpUrl =
        value.toHttpUrlOrNull() ?: throw WebDAVError.InvalidUrl

    private suspend fun execute(request: Request) = withContext(Dispatchers.IO) {
        try {
            client.newCall(request).execute().use { response ->
                validate(response.code)
            }
        } catch (e: WebDAVError) {
            throw e
        } catch (e: IOException) {
            throw WebDAVError.NetworkError(e)
        }
    }

    private fun validate(code: Int) {
        when {
            code in 200..299 || code == 207 -> return
            code == 401 -> throw WebDAVError.AuthenticationFailed
            else -> throw WebDAVError.ServerError(code)
        }
    }

    companion object {
        private val PDF_MEDIA_TYPE = "application/pdf".toMediaType()
    }
}
