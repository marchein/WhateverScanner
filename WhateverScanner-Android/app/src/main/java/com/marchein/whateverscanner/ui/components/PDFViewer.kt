package com.marchein.whateverscanner.ui.components

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Renders a PDF (provided as bytes) page-by-page into a vertically scrolling
 * list, using Android's native [PdfRenderer]. The Android counterpart of the
 * iOS PDFKit preview.
 */
@Composable
fun PDFViewer(
    pdfData: ByteArray,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var pages by remember(pdfData) { mutableStateOf<List<Bitmap>>(emptyList()) }

    LaunchedEffect(pdfData) {
        pages = withContext(Dispatchers.IO) { renderPdf(context.cacheDir, pdfData) }
    }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(pages) { page ->
            Image(
                bitmap = page.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
            )
        }
    }
}

private fun renderPdf(cacheDir: File, pdfData: ByteArray): List<Bitmap> {
    val tempFile = File.createTempFile("preview", ".pdf", cacheDir)
    return try {
        tempFile.writeBytes(pdfData)
        ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                (0 until renderer.pageCount).map { index ->
                    renderer.openPage(index).use { page ->
                        // Render at ~2x the page's point size for a crisp preview.
                        val width = page.width * 2
                        val height = page.height * 2
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        bitmap
                    }
                }
            }
        }
    } catch (e: Exception) {
        emptyList()
    } finally {
        tempFile.delete()
    }
}
