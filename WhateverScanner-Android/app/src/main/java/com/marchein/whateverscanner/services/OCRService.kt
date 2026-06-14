package com.marchein.whateverscanner.services

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/**
 * Performs OCR on scanned document images using ML Kit Text Recognition and
 * extracts metadata (a suggested name and a document date).
 *
 * The extraction heuristics are a direct port of the iOS `OCRService`, covering
 * German and English document vocabulary.
 */
@Singleton
class OCRService @Inject constructor() {

    /** Result of OCR analysis. */
    data class DocumentInfo(
        val suggestedName: String?,
        val documentDate: Date?
    )

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /**
     * Runs OCR on the first page of [images] and extracts document metadata.
     * Only the first page is analyzed, as key info usually appears there.
     */
    suspend fun analyzeDocument(images: List<Bitmap>): DocumentInfo {
        val firstImage = images.firstOrNull() ?: return DocumentInfo(null, null)
        val lines = performOcr(firstImage)
        return DocumentInfo(
            suggestedName = extractDocumentName(lines),
            documentDate = extractDate(lines)
        )
    }

    /** Recognizes text and returns the lines ordered top-to-bottom. */
    private suspend fun performOcr(bitmap: Bitmap): List<String> =
        suspendCancellableCoroutine { continuation ->
            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
                .addOnSuccessListener { result ->
                    val lines = result.textBlocks
                        .flatMap { block -> block.lines }
                        .map { it.text }
                    continuation.resume(lines)
                }
                .addOnFailureListener {
                    continuation.resume(emptyList())
                }
        }

    // region Name extraction

    /** Extracts a meaningful document name using the same heuristics as iOS. */
    internal fun extractDocumentName(lines: List<String>): String? {
        if (lines.isEmpty()) return null

        var documentType: String? = null
        outer@ for (line in lines) {
            val lowered = line.lowercase()
            for ((pattern, label) in DOCUMENT_TYPE_KEYWORDS) {
                if (lowered.contains(pattern)) {
                    documentType = label
                    break@outer
                }
            }
        }

        val companyName = lines.take(5).firstOrNull { line ->
            val trimmed = line.trim()
            if (trimmed.length < 3) return@firstOrNull false
            if (trimmed.all { it.isDigit() || it == '.' || it == ',' || it == '/' || it == '-' || it == ' ' }) {
                return@firstOrNull false
            }
            val lowered = trimmed.lowercase()
            if (SKIP_WORDS.any { lowered.startsWith(it) }) return@firstOrNull false
            true
        }

        val subject = extractDocumentSubject(lines, documentType)

        return when {
            companyName != null && documentType != null -> {
                val cleanCompany = cleanName(companyName)
                if (subject != null) "$cleanCompany - $documentType $subject"
                else "$cleanCompany - $documentType"
            }

            documentType != null -> if (subject != null) "$documentType $subject" else documentType
            companyName != null -> cleanName(companyName)
            else -> null
        }
    }

    /** Trims, removes trademark symbols, collapses spaces and truncates to 40 chars. */
    internal fun cleanName(name: String): String {
        var cleaned = name.trim()
        for (symbol in TRADEMARK_SYMBOLS) {
            cleaned = cleaned.replace(symbol, "")
        }
        cleaned = Regex("""\s*\((?:c|r|tm|sm)\)\s*""", RegexOption.IGNORE_CASE).replace(cleaned, " ")
        cleaned = Regex("""\s+(?:TM|SM)\b""").replace(cleaned, "")
        cleaned = cleaned.trim()
        while (cleaned.contains("  ")) {
            cleaned = cleaned.replace("  ", " ")
        }
        return if (cleaned.length > 40) cleaned.take(40).trim() else cleaned
    }

    /** Attempts to extract what the document is about (product/service). */
    internal fun extractDocumentSubject(lines: List<String>, documentType: String?): String? {
        if (documentType == null) return null

        // Strategy 1: subject-hint keywords with a value after a colon or on the next line.
        for ((index, line) in lines.withIndex()) {
            val lowered = line.lowercase().trim()
            for (hint in SUBJECT_HINTS) {
                if (lowered.startsWith(hint) || lowered.contains(":$hint") || lowered.contains(": $hint")) {
                    val colonIndex = line.indexOf(':')
                    if (colonIndex >= 0) {
                        val afterColon = line.substring(colonIndex + 1).trim()
                        if (afterColon.length >= 3) return cleanSubject(afterColon)
                    }
                    if (index + 1 < lines.size) {
                        val nextLine = lines[index + 1].trim()
                        if (nextLine.length >= 3 &&
                            !nextLine.all { it.isDigit() || it == '.' || it == ',' || it == ' ' }
                        ) {
                            return cleanSubject(nextLine)
                        }
                    }
                }
            }
        }

        // Strategy 2: product-like table lines (leading quantity + description).
        val tableLineStart = Regex("""^\s*\d+\s+[A-Za-zÄÖÜäöüß]""")
        val tableLineExtract = Regex("""^\s*\d+\s+(.+?)(?:\s+\d+[.,]\d{2}\s*(?:€|\$|EUR|USD)?)?$""")
        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.length < 5) continue
            if (tableLineStart.containsMatchIn(trimmed)) {
                val match = tableLineExtract.find(trimmed)
                val productName = match?.groupValues?.getOrNull(1)?.trim()
                if (productName != null && productName.length >= 3) {
                    return cleanSubject(productName)
                }
            }
        }

        return null
    }

    /** Removes trailing prices and truncates a subject to 30 chars. */
    internal fun cleanSubject(subject: String): String {
        var cleaned = subject.trim()
        cleaned = Regex("""\s*\d+[.,]\d{2}\s*(?:€|\$|EUR|USD)?\s*$""").replace(cleaned, "")
        cleaned = cleaned.trim()
        if (cleaned.length > 30) cleaned = cleaned.take(30).trim()
        return cleaned
    }

    // endregion

    // region Date extraction

    /** Extracts the first plausible date (years 1990–2100) from the text. */
    internal fun extractDate(lines: List<String>): Date? {
        val fullText = lines.joinToString(" ")

        for ((regex, format) in DATE_PATTERNS) {
            val matches = regex.findAll(fullText)
            for (match in matches) {
                val dateString = match.groupValues[1]
                val formatter = SimpleDateFormat(format, Locale.US).apply { isLenient = false }
                val date = try {
                    formatter.parse(dateString)
                } catch (e: Exception) {
                    null
                } ?: continue

                val year = Calendar.getInstance().apply { time = date }.get(Calendar.YEAR)
                if (year in 1990..2100) return date
            }
        }
        return null
    }

    // endregion

    companion object {
        private val DOCUMENT_TYPE_KEYWORDS: List<Pair<String, String>> = listOf(
            "rechnung" to "Rechnung",
            "invoice" to "Invoice",
            "quittung" to "Quittung",
            "receipt" to "Receipt",
            "kassenbon" to "Kassenbon",
            "lieferschein" to "Lieferschein",
            "delivery note" to "Delivery Note",
            "angebot" to "Angebot",
            "offer" to "Offer",
            "vertrag" to "Vertrag",
            "contract" to "Contract",
            "mahnung" to "Mahnung",
            "reminder" to "Reminder",
            "bestellung" to "Bestellung",
            "order" to "Order",
            "gutschrift" to "Gutschrift",
            "credit note" to "Credit Note",
            "kontoauszug" to "Kontoauszug",
            "bank statement" to "Bank Statement",
            "mietvertrag" to "Mietvertrag",
            "lease" to "Lease",
            "kündigung" to "Kündigung",
            "bescheid" to "Bescheid",
            "brief" to "Brief",
            "letter" to "Letter"
        )

        private val SKIP_WORDS = listOf(
            "datum", "date", "tel", "fax", "email", "www", "http", "seite", "page"
        )

        private val TRADEMARK_SYMBOLS = listOf("®", "©", "™", "℠")

        private val SUBJECT_HINTS = listOf(
            "bezeichnung", "beschreibung", "artikel", "produkt", "gegenstand",
            "leistung", "betreff", "objekt",
            "description", "item", "product", "subject", "service", "article",
            "regarding", "for:", "re:"
        )

        // Ordered by specificity, matching the iOS implementation.
        private val DATE_PATTERNS: List<Pair<Regex, String>> = listOf(
            Regex("""(\d{2}\.\d{2}\.\d{4})""") to "dd.MM.yyyy",
            Regex("""(\d{2}/\d{2}/\d{4})""") to "dd/MM/yyyy",
            Regex("""(\d{4}-\d{2}-\d{2})""") to "yyyy-MM-dd",
            Regex("""(\d{2}-\d{2}-\d{4})""") to "dd-MM-yyyy",
            Regex("""(\d{2}\.\d{2}\.\d{2})\b""") to "dd.MM.yy"
        )
    }
}
