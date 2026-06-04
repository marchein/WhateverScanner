import UIKit
import PDFKit

/// Service responsible for creating PDF documents from scanned images
/// and generating timestamped filenames.
class PDFService {
    /// Shared singleton instance.
    static let shared = PDFService()

    private init() {}

    /// Converts an array of `UIImage` instances into a single PDF document.
    /// - Parameter images: The page images to include in the PDF.
    /// - Returns: The PDF data, or `nil` if the input is empty or conversion fails.
    func createPDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }

        let pdfDocument = PDFDocument()

        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: index)
        }

        return pdfDocument.dataRepresentation()
    }

    /// Generates a date-stamped filename for a scanned document.
    /// - Returns: A filename in the format `Scan_yyyy-MM-dd_HH-mm-ss.pdf`.
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Scan_\(formatter.string(from: Date())).pdf"
    }
}
