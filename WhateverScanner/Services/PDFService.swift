import UIKit

/// Service responsible for creating PDF documents from scanned images
/// and generating timestamped filenames.
class PDFService {
    /// Shared singleton instance.
    static let shared = PDFService()

    private init() {}

    /// The standard width used for PDF pages (A4 width in points: 595.28).
    /// Each page is scaled to this width while preserving its aspect ratio,
    /// so documents of different physical sizes (e.g. receipts vs A4 pages)
    /// appear at a consistent width in the resulting PDF.
    private static let standardPageWidth: CGFloat = 595.28

    /// Converts an array of `UIImage` instances into a single PDF document.
    ///
    /// Each page is sized to the standard A4 width while preserving the
    /// original image aspect ratio. This prevents documents of different
    /// physical sizes from appearing disproportionately wide or narrow.
    /// - Parameter images: The page images to include in the PDF.
    /// - Returns: The PDF data, or `nil` if the input is empty or conversion fails.
    func createPDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: .zero)
        let data = pdfRenderer.pdfData { context in
            for image in images {
                let imageSize = image.size
                guard imageSize.width > 0, imageSize.height > 0 else { continue }

                let aspectRatio = imageSize.height / imageSize.width
                let pageWidth = Self.standardPageWidth
                let pageHeight = pageWidth * aspectRatio
                let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

                context.beginPage(withBounds: pageRect, pageInfo: [:])
                image.draw(in: pageRect)
            }
        }

        return data.isEmpty ? nil : data
    }

    /// Generates a date-stamped filename for a scanned document.
    /// - Returns: A filename in the format `Scan_yyyy-MM-dd_HH-mm-ss.pdf`.
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Scan_\(formatter.string(from: Date())).pdf"
    }
}
