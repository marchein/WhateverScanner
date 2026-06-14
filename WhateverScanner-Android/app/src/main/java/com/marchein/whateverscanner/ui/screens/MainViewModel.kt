package com.marchein.whateverscanner.ui.screens

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.marchein.whateverscanner.models.AppSettingsData
import com.marchein.whateverscanner.models.SettingsRepository
import com.marchein.whateverscanner.models.WebDAVServer
import com.marchein.whateverscanner.services.OCRService
import com.marchein.whateverscanner.services.PDFService
import com.marchein.whateverscanner.services.WebDAVService
import com.marchein.whateverscanner.services.localizedMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.withContext
import java.util.Date
import javax.inject.Inject

/** Result of an upload attempt across one or more servers. */
data class UploadOutcome(
    val successCount: Int,
    val failures: List<String>
) {
    val isCompleteSuccess: Boolean get() = failures.isEmpty() && successCount > 0
    val isCompleteFailure: Boolean get() = successCount == 0
}

/** Transient state of the document currently being previewed. */
data class ScanPreviewState(
    val pdfData: ByteArray,
    val suggestedName: String?,
    val documentDate: Date?,
    val scanDate: Date
)

@HiltViewModel
class MainViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val pdfService: PDFService,
    private val ocrService: OCRService,
    private val webDavService: WebDAVService
) : ViewModel() {

    val settings: StateFlow<AppSettingsData> = settingsRepository.settings.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = AppSettingsData()
    )

    private val _isAnalyzing = MutableStateFlow(false)
    val isAnalyzing: StateFlow<Boolean> = _isAnalyzing.asStateFlow()

    private val _previewState = MutableStateFlow<ScanPreviewState?>(null)
    val previewState: StateFlow<ScanPreviewState?> = _previewState.asStateFlow()

    private val _scanError = MutableStateFlow<String?>(null)
    val scanError: StateFlow<String?> = _scanError.asStateFlow()

    /**
     * Processes scanned page URIs: builds a PDF and runs OCR. On success the
     * [previewState] is populated so the preview screen can open.
     *
     * @return true if a preview was produced, false on failure.
     */
    suspend fun processScan(pageUris: List<Uri>): Boolean {
        _isAnalyzing.value = true
        try {
            val bitmaps = withContext(Dispatchers.IO) {
                pageUris.mapNotNull { decodeBitmap(it) }
            }
            if (bitmaps.isEmpty()) {
                _scanError.value = ScanErrorKind.PDF.name
                return false
            }

            val pdfData = withContext(Dispatchers.Default) { pdfService.createPdf(bitmaps) }
            if (pdfData == null) {
                _scanError.value = ScanErrorKind.PDF.name
                return false
            }

            val info = ocrService.analyzeDocument(bitmaps)
            _previewState.value = ScanPreviewState(
                pdfData = pdfData,
                suggestedName = info.suggestedName,
                documentDate = info.documentDate,
                scanDate = Date()
            )
            return true
        } finally {
            _isAnalyzing.value = false
        }
    }

    fun reportScanError(message: String?) {
        _scanError.value = message ?: ScanErrorKind.GENERIC.name
    }

    fun clearScanError() {
        _scanError.value = null
    }

    fun clearPreview() {
        _previewState.value = null
    }

    /** Uploads [pdfData] under [filename] to the current upload targets. */
    suspend fun upload(pdfData: ByteArray, filename: String): UploadOutcome {
        val targets: List<WebDAVServer> = settings.value.uploadTargets
        var success = 0
        val failures = mutableListOf<String>()
        for (server in targets) {
            try {
                webDavService.upload(pdfData, filename, server)
                success++
            } catch (e: Exception) {
                failures.add("${server.name}: ${e.localizedMessage(context)}")
            }
        }
        return UploadOutcome(success, failures)
    }

    private fun decodeBitmap(uri: Uri): Bitmap? = try {
        context.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    } catch (e: Exception) {
        null
    }

    enum class ScanErrorKind { PDF, GENERIC }
}
