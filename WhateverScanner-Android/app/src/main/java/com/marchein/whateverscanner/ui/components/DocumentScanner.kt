package com.marchein.whateverscanner.ui.components

import android.app.Activity
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult

/**
 * Handle returned by [rememberDocumentScanner] used to start a scan.
 */
class DocumentScannerLauncher(
    private val launch: () -> Unit
) {
    operator fun invoke() = launch()
}

/**
 * Sets up the Google ML Kit document scanner — the Android equivalent of the
 * iOS VisionKit document camera. Provides auto edge-detection, enhancement and
 * optional gallery import.
 *
 * @param onScanned called with the JPEG page URIs of a successful scan.
 * @param onCancelled called when the user dismisses the scanner.
 * @param onError called with a throwable when the scanner fails to start or run.
 */
@Composable
fun rememberDocumentScanner(
    onScanned: (List<Uri>) -> Unit,
    onCancelled: () -> Unit = {},
    onError: (Throwable) -> Unit = {}
): DocumentScannerLauncher {
    val context = LocalContext.current

    val activityLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartIntentSenderForResult()
    ) { result ->
        when (result.resultCode) {
            Activity.RESULT_OK -> {
                val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(result.data)
                val uris = scanResult?.pages?.map { it.imageUri } ?: emptyList()
                if (uris.isEmpty()) onCancelled() else onScanned(uris)
            }

            Activity.RESULT_CANCELED -> onCancelled()
            else -> onCancelled()
        }
    }

    val scanner = remember {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(20)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options)
    }

    return remember(scanner, activityLauncher) {
        DocumentScannerLauncher {
            val activity = context as? Activity
            if (activity == null) {
                onError(IllegalStateException("No host activity available for scanning."))
                return@DocumentScannerLauncher
            }
            scanner.getStartScanIntent(activity)
                .addOnSuccessListener { intentSender ->
                    activityLauncher.launch(IntentSenderRequest.Builder(intentSender).build())
                }
                .addOnFailureListener { e -> onError(e) }
        }
    }
}
