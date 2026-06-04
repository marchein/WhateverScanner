import Vision
import UIKit

/// Service that performs OCR on scanned document images using Apple's Vision framework
/// and attempts to extract meaningful metadata such as document name and date.
class OCRService {
    /// Shared singleton instance.
    static let shared = OCRService()

    private init() {}

    /// Result of OCR analysis containing suggested document name and date.
    struct DocumentInfo {
        /// A suggested name for the document based on recognized text (e.g. shop name, company).
        let suggestedName: String?
        /// A date found in the document (e.g. receipt date, letter date).
        let documentDate: Date?
    }

    /// Performs OCR on the given images and extracts document metadata.
    /// Only analyzes the first page for efficiency, as key info is usually there.
    /// - Parameter images: The scanned page images.
    /// - Returns: A `DocumentInfo` with any recognized metadata.
    func analyzeDocument(images: [UIImage]) async -> DocumentInfo {
        guard let firstImage = images.first, let cgImage = firstImage.cgImage else {
            return DocumentInfo(suggestedName: nil, documentDate: nil)
        }

        let recognizedText = await performOCR(on: cgImage)
        let suggestedName = extractDocumentName(from: recognizedText)
        let documentDate = extractDate(from: recognizedText)

        return DocumentInfo(suggestedName: suggestedName, documentDate: documentDate)
    }

    // MARK: - OCR

    /// Performs text recognition on a single image using VNRecognizeTextRequest.
    /// - Parameter image: The CGImage to analyze.
    /// - Returns: An array of recognized text strings, ordered top-to-bottom.
    private func performOCR(on image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let texts = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: texts)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Document Name Extraction

    /// Attempts to extract a meaningful document name from recognized text lines.
    /// Uses heuristics to identify shop names, company names, or document titles.
    /// - Parameter lines: The recognized text lines from OCR.
    /// - Returns: A suggested document name, or nil if none could be determined.
    private func extractDocumentName(from lines: [String]) -> String? {
        guard !lines.isEmpty else { return nil }

        // Look for common document type keywords in the first several lines
        let documentTypeKeywords: [(pattern: String, label: String)] = [
            ("rechnung", "Rechnung"),
            ("invoice", "Invoice"),
            ("quittung", "Quittung"),
            ("receipt", "Receipt"),
            ("kassenbon", "Kassenbon"),
            ("lieferschein", "Lieferschein"),
            ("delivery note", "Delivery Note"),
            ("angebot", "Angebot"),
            ("offer", "Offer"),
            ("vertrag", "Vertrag"),
            ("contract", "Contract"),
            ("mahnung", "Mahnung"),
            ("reminder", "Reminder"),
            ("bestellung", "Bestellung"),
            ("order", "Order"),
            ("gutschrift", "Gutschrift"),
            ("credit note", "Credit Note"),
            ("kontoauszug", "Kontoauszug"),
            ("bank statement", "Bank Statement"),
            ("mietvertrag", "Mietvertrag"),
            ("lease", "Lease"),
            ("kündigung", "Kündigung"),
            ("bescheid", "Bescheid"),
            ("brief", "Brief"),
            ("letter", "Letter"),
        ]

        // Check all lines for document type keywords
        var documentType: String?
        for line in lines {
            let lowered = line.lowercased()
            for keyword in documentTypeKeywords {
                if lowered.contains(keyword.pattern) {
                    documentType = keyword.label
                    break
                }
            }
            if documentType != nil { break }
        }

        // The first few non-trivial lines often contain the company/shop name
        let candidateLines = lines.prefix(5)
        let companyName = candidateLines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip very short lines, pure numbers, or date-like strings
            guard trimmed.count >= 3 else { return false }
            guard !trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "/" || $0 == "-" || $0 == " " }) else { return false }
            // Skip lines that are just common headers
            let lowered = trimmed.lowercased()
            let skipWords = ["datum", "date", "tel", "fax", "email", "www", "http", "seite", "page"]
            guard !skipWords.contains(where: { lowered.hasPrefix($0) }) else { return false }
            return true
        }

        // Combine company name, document type, and subject if found
        let subject = extractDocumentSubject(from: lines, documentType: documentType)

        if let company = companyName, let docType = documentType {
            let cleanCompany = cleanName(company)
            if let subject = subject {
                return "\(cleanCompany) - \(docType) \(subject)"
            }
            return "\(cleanCompany) - \(docType)"
        } else if let docType = documentType {
            if let subject = subject {
                return "\(docType) \(subject)"
            }
            return docType
        } else if let company = companyName {
            return cleanName(company)
        }

        return nil
    }

    /// Cleans up a name string by trimming, removing trademark symbols, and truncating.
    private func cleanName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trademark/copyright symbols and their parenthesized forms
        let trademarkPatterns = ["®", "©", "™", "℠"]
        for symbol in trademarkPatterns {
            cleaned = cleaned.replacingOccurrences(of: symbol, with: "")
        }
        // Remove parenthesized trademark abbreviations like (c), (r), (tm), (sm)
        if let regex = try? NSRegularExpression(pattern: #"\s*\((?:c|r|tm|sm)\)\s*"#, options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: " ")
        }
        // Remove standalone TM/SM that follow a word
        if let regex = try? NSRegularExpression(pattern: #"\s+(?:TM|SM)\b"#) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        // Collapse multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        if cleaned.count > 40 {
            return String(cleaned.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    // MARK: - Document Subject Extraction

    /// Attempts to extract what the document is about (e.g. a product or service name)
    /// by looking for descriptive lines near document type keywords.
    /// - Parameters:
    ///   - lines: The recognized text lines from OCR.
    ///   - documentType: The detected document type keyword, if any.
    /// - Returns: A short subject description, or nil if none could be determined.
    private func extractDocumentSubject(from lines: [String], documentType: String?) -> String? {
        guard documentType != nil else { return nil }

        // Keywords that hint at a product/service description line
        let subjectHintPatterns: [(pattern: String, prefix: String)] = [
            // German
            ("bezeichnung", ""),
            ("beschreibung", ""),
            ("artikel", ""),
            ("produkt", ""),
            ("gegenstand", ""),
            ("leistung", ""),
            ("betreff", ""),
            ("objekt", ""),
            // English
            ("description", ""),
            ("item", ""),
            ("product", ""),
            ("subject", ""),
            ("service", ""),
            ("article", ""),
            ("regarding", ""),
            ("for:", ""),
            ("re:", ""),
        ]

        // Strategy 1: Look for lines with subject-hint keywords and extract the value
        for (index, line) in lines.enumerated() {
            let lowered = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for hint in subjectHintPatterns {
                if lowered.hasPrefix(hint.pattern) || lowered.contains(":\(hint.pattern)") || lowered.contains(": \(hint.pattern)") {
                    // The value might be on the same line after a colon or on the next line
                    if let colonIndex = line.firstIndex(of: ":") {
                        let afterColon = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if afterColon.count >= 3 {
                            return cleanSubject(afterColon)
                        }
                    }
                    // Check next line
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if nextLine.count >= 3 && !nextLine.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " }) {
                            return cleanSubject(nextLine)
                        }
                    }
                }
            }
        }

        // Strategy 2: Look for product-like lines in a table (lines containing quantity + description)
        let tableLinePattern = try? NSRegularExpression(pattern: #"^\s*\d+\s+[A-Za-zÄÖÜäöüß]"#)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 5 else { continue }
            if let regex = tableLinePattern,
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                // Extract the text part after the leading number(s)
                if let match = try? NSRegularExpression(pattern: #"^\s*\d+\s+(.+?)(?:\s+\d+[.,]\d{2}\s*(?:€|\$|EUR|USD)?)?$"#),
                   let result = match.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                   let range = Range(result.range(at: 1), in: trimmed) {
                    let productName = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if productName.count >= 3 {
                        return cleanSubject(productName)
                    }
                }
            }
        }

        return nil
    }

    /// Cleans and truncates a subject string for use in filenames.
    private func cleanSubject(_ subject: String) -> String {
        var cleaned = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trailing price-like patterns
        if let regex = try? NSRegularExpression(pattern: #"\s*\d+[.,]\d{2}\s*(?:€|\$|EUR|USD)?\s*$"#) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 30 {
            cleaned = String(cleaned.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    // MARK: - Date Extraction

    /// Attempts to extract a date from the recognized text lines.
    /// Supports common German and English date formats.
    /// - Parameter lines: The recognized text lines from OCR.
    /// - Returns: The first valid date found, or nil.
    private func extractDate(from lines: [String]) -> Date? {
        let fullText = lines.joined(separator: " ")

        // Common date patterns (ordered by specificity)
        let datePatterns: [(regex: String, format: String)] = [
            // DD.MM.YYYY (German standard)
            (#"(\d{2}\.\d{2}\.\d{4})"#, "dd.MM.yyyy"),
            // DD/MM/YYYY
            (#"(\d{2}/\d{2}/\d{4})"#, "dd/MM/yyyy"),
            // YYYY-MM-DD (ISO)
            (#"(\d{4}-\d{2}-\d{2})"#, "yyyy-MM-dd"),
            // DD-MM-YYYY
            (#"(\d{2}-\d{2}-\d{4})"#, "dd-MM-yyyy"),
            // DD.MM.YY (German short)
            (#"(\d{2}\.\d{2}\.\d{2})\b"#, "dd.MM.yy"),
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for pattern in datePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex) else { continue }
            let matches = regex.matches(in: fullText, range: NSRange(fullText.startIndex..., in: fullText))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: fullText) else { continue }
                let dateString = String(fullText[range])
                formatter.dateFormat = pattern.format

                if let date = formatter.date(from: dateString) {
                    // Sanity check: date should be within reasonable range (1990-2030+)
                    let year = Calendar.current.component(.year, from: date)
                    if year >= 1990 && year <= 2100 {
                        return date
                    }
                }
            }
        }

        return nil
    }
}
