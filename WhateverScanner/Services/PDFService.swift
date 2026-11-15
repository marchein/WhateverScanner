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

    /// Maximum pixel width of an embedded page image. 1654 px across an A4 page
    /// corresponds to 200 dpi, which keeps text crisp (and OCR-able by other apps)
    /// while keeping the PDF small enough to upload quickly. Camera images are
    /// typically 3000+ px wide, which would otherwise result in several MB per page.
    static let maxImagePixelWidth: CGFloat = 1654

    /// JPEG quality used for embedded page images.
    static let jpegCompressionQuality: CGFloat = 0.75

    /// Converts an array of `UIImage` instances into a single PDF document.
    ///
    /// Each page is sized to the standard A4 width while preserving the
    /// original image aspect ratio. This prevents documents of different
    /// physical sizes from appearing disproportionately wide or narrow.
    /// Page images are downscaled to at most `maxImagePixelWidth` and embedded
    /// as JPEG to keep the resulting file size and memory usage reasonable.
    ///
    /// This is CPU intensive for multi-page scans; call it off the main thread.
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
                // Release the intermediate (resized/compressed) bitmaps after every
                // page so memory stays flat for long multi-page scans.
                autoreleasepool {
                    Self.compressedPageImage(from: image).draw(in: pageRect)
                }
            }
        }

        return data.isEmpty ? nil : data
    }

    /// Generates a date-stamped filename for a scanned document.
    /// - Returns: A filename in the format `Scan_yyyy-MM-dd_HH-mm-ss.pdf`.
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Scan_\(formatter.string(from: Date())).pdf"
    }

    // MARK: - Helpers

    /// Returns a downscaled, JPEG-backed copy of `image` suitable for embedding in a PDF.
    /// An image created from JPEG data is passed through to the PDF as JPEG by Core
    /// Graphics instead of being stored as uncompressed bitmap data.
    /// Falls back to the original image if any step fails.
    static func compressedPageImage(from image: UIImage) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let targetImage: UIImage
        if pixelWidth > maxImagePixelWidth {
            let factor = maxImagePixelWidth / pixelWidth
            let targetSize = CGSize(
                width: (image.size.width * image.scale * factor).rounded(),
                height: (image.size.height * image.scale * factor).rounded()
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            targetImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }

        guard let jpegData = targetImage.jpegData(compressionQuality: jpegCompressionQuality),
              let jpegImage = UIImage(data: jpegData) else {
            return targetImage
        }
        return jpegImage
    }
}
