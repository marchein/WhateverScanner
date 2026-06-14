package com.marchein.whateverscanner.services

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.graphics.pdf.PdfDocument
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.roundToInt

/**
 * Creates PDF documents from scanned page bitmaps and generates timestamped
 * filenames. Mirrors the iOS `PDFService`.
 */
@Singleton
class PDFService @Inject constructor() {

    /**
     * Converts a list of [Bitmap] pages into a single PDF document.
     *
     * Each page is sized to the standard A4 width while preserving the source
     * aspect ratio, so receipts and full pages appear at a consistent width.
     *
     * @return the PDF bytes, or null if [images] is empty or rendering fails.
     */
    fun createPdf(images: List<Bitmap>): ByteArray? {
        if (images.isEmpty()) return null

        val document = PdfDocument()
        try {
            images.forEachIndexed { index, image ->
                if (image.width <= 0 || image.height <= 0) return@forEachIndexed

                val aspectRatio = image.height.toFloat() / image.width.toFloat()
                val pageWidth = STANDARD_PAGE_WIDTH
                val pageHeight = (pageWidth * aspectRatio).roundToInt().coerceAtLeast(1)

                val pageInfo = PdfDocument.PageInfo
                    .Builder(pageWidth, pageHeight, index + 1)
                    .create()
                val page = document.startPage(pageInfo)
                val canvas: Canvas = page.canvas
                val destRect = Rect(0, 0, pageWidth, pageHeight)
                canvas.drawBitmap(image, null, destRect, null)
                document.finishPage(page)
            }

            val output = ByteArrayOutputStream()
            document.writeTo(output)
            val bytes = output.toByteArray()
            return if (bytes.isEmpty()) null else bytes
        } catch (e: Exception) {
            return null
        } finally {
            document.close()
        }
    }

    /** Generates a filename like `Scan_2026-06-14_19-14-37.pdf`. */
    fun generateFilename(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US)
        return "Scan_${formatter.format(Date())}.pdf"
    }

    companion object {
        /** A4 width in PostScript points (rounded from 595.28). */
        const val STANDARD_PAGE_WIDTH = 595
    }
}
