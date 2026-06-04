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

        // Combine company name and document type if both found
        if let company = companyName, let docType = documentType {
            let cleanCompany = cleanName(company)
            return "\(cleanCompany) - \(docType)"
        } else if let docType = documentType {
            return docType
        } else if let company = companyName {
            return cleanName(company)
        }

        return nil
    }

    /// Cleans up a name string by trimming and truncating.
    private func cleanName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 40 {
            return String(trimmed.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
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
