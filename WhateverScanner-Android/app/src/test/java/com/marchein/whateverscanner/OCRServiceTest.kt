package com.marchein.whateverscanner.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * Unit tests for the pure metadata-extraction heuristics of [OCRService].
 * These exercise the same logic as the iOS `OCRService`.
 */
class OCRServiceTest {

    private val service = OCRService()

    @Test
    fun extractsGermanInvoiceTypeAndCompany() {
        val lines = listOf(
            "ACME GmbH",
            "Musterstraße 1",
            "Rechnung Nr. 12345",
            "Datum: 14.06.2026"
        )
        val name = service.extractDocumentName(lines)
        assertNotNull(name)
        assertTrue(name!!.contains("ACME GmbH"))
        assertTrue(name.contains("Rechnung"))
    }

    @Test
    fun extractsEnglishReceiptType() {
        val lines = listOf("Some Shop Ltd", "Receipt", "Total 12.99")
        val name = service.extractDocumentName(lines)
        assertNotNull(name)
        assertTrue(name!!.contains("Receipt"))
    }

    @Test
    fun returnsNullWhenNoMeaningfulText() {
        assertNull(service.extractDocumentName(emptyList()))
        assertNull(service.extractDocumentName(listOf("12", "3.4", "---")))
    }

    @Test
    fun cleanNameRemovesTrademarkSymbolsAndTruncates() {
        assertEquals("Acme", service.cleanName("Acme®"))
        assertEquals("Acme", service.cleanName("Acme (c)"))
        val long = "A".repeat(60)
        assertEquals(40, service.cleanName(long).length)
    }

    @Test
    fun cleanSubjectRemovesTrailingPrice() {
        assertEquals("Widget", service.cleanSubject("Widget 19.99 €"))
        assertEquals("Widget", service.cleanSubject("Widget 5,00"))
    }

    @Test
    fun extractsGermanDate() {
        val date = service.extractDate(listOf("Rechnungsdatum 14.06.2026"))
        assertNotNull(date)
        val cal = Calendar.getInstance().apply { time = date!! }
        assertEquals(2026, cal.get(Calendar.YEAR))
        assertEquals(Calendar.JUNE, cal.get(Calendar.MONTH))
        assertEquals(14, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun extractsIsoDate() {
        val date = service.extractDate(listOf("Created 2026-06-14 by system"))
        assertNotNull(date)
        val cal = Calendar.getInstance().apply { time = date!! }
        assertEquals(2026, cal.get(Calendar.YEAR))
    }

    @Test
    fun rejectsImplausibleYear() {
        // 31.12.1850 -> year out of the 1990..2100 sanity range.
        assertNull(service.extractDate(listOf("Old date 31.12.1850")))
    }

    @Test
    fun returnsNullWhenNoDatePresent() {
        assertNull(service.extractDate(listOf("No dates here", "just text")))
    }
}
