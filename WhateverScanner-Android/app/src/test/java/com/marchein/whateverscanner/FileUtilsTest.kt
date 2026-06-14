package com.marchein.whateverscanner.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class FileUtilsTest {

    @Test
    fun normalizeServerUrlAddsTrailingSlash() {
        assertEquals("https://example.com/", normalizeServerUrl("https://example.com"))
        assertEquals("https://example.com/", normalizeServerUrl("  https://example.com/  "))
    }

    @Test
    fun sanitizeFilenameReplacesInvalidChars() {
        assertEquals("a_b_c_d", sanitizeFilename("a/b:c*d"))
        assertEquals("safe-name", sanitizeFilename("safe-name"))
    }

    @Test
    fun buildUploadFilenameUsesSanitizedNameAndTimestamp() {
        val date = Calendar.getInstance().apply {
            set(2026, Calendar.JUNE, 14, 19, 14, 37)
        }.time
        val filename = buildUploadFilename("My/Invoice", date)
        assertTrue(filename.startsWith("My_Invoice_2026-06-14_19-14-37"))
        assertTrue(filename.endsWith(".pdf"))
    }

    @Test
    fun buildUploadFilenameFallsBackToScanWhenBlank() {
        val filename = buildUploadFilename("   ", Calendar.getInstance().time)
        assertTrue(filename.startsWith("Scan_"))
    }
}
