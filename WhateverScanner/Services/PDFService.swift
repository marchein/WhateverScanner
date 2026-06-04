import UIKit
import PDFKit

class PDFService {
    static let shared = PDFService()

    private init() {}

    /// Convert an array of UIImages into PDF data.
    func createPDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }

        let pdfDocument = PDFDocument()

        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: index)
        }

        return pdfDocument.dataRepresentation()
    }

    /// Generate a date-stamped filename for a scan.
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Scan_\(formatter.string(from: Date())).pdf"
    }
}
