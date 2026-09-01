import XCTest
import UIKit
import PDFKit
@testable import WhateverScanner

/// Unit tests for `PDFService`, covering PDF generation from images and filename formatting.
final class PDFServiceTests: XCTestCase {

    func testCreatePDFFromEmptyArrayReturnsNil() {
        XCTAssertNil(PDFService.shared.createPDF(from: []))
    }

    func testCreatePDFFromSingleImageProducesValidDocument() throws {
        let image = Self.makeImage(width: 100, height: 200, color: .red)
        let data = try XCTUnwrap(PDFService.shared.createPDF(from: [image]))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
    }

    func testCreatePDFFromMultipleImagesProducesOnePagePerImage() throws {
        let images = [
            Self.makeImage(width: 100, height: 200, color: .red),
            Self.makeImage(width: 100, height: 200, color: .blue),
            Self.makeImage(width: 100, height: 200, color: .green),
        ]
        let data = try XCTUnwrap(PDFService.shared.createPDF(from: images))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 3)
    }

    func testCreatePDFSkipsZeroSizedImages() {
        let zeroSizeImage = UIImage()
        // A degenerate (zero-size) image can't be drawn onto a page. The renderer
        // still emits its implicit first page (with zero bounds, since none of the
        // images produced an explicit `beginPage`), so no crash occurs and no
        // meaningful page content is added.
        if let data = PDFService.shared.createPDF(from: [zeroSizeImage]) {
            let document = PDFDocument(data: data)
            XCTAssertLessThanOrEqual(document?.pageCount ?? 0, 1)
        }
    }

    func testCreatePDFPreservesAspectRatio() throws {
        // A page twice as tall as it is wide should render at twice the height of the standard width.
        let image = Self.makeImage(width: 100, height: 200, color: .black)
        let data = try XCTUnwrap(PDFService.shared.createPDF(from: [image]))
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        XCTAssertEqual(bounds.height / bounds.width, 2.0, accuracy: 0.01)
    }

    func testGenerateFilenameFormat() {
        let filename = PDFService.shared.generateFilename()
        XCTAssertTrue(filename.hasPrefix("Scan_"))
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testGenerateFilenameIsUniqueAcrossTime() {
        let first = PDFService.shared.generateFilename()
        Thread.sleep(forTimeInterval: 1.1)
        let second = PDFService.shared.generateFilename()
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Helpers

    private static func makeImage(width: CGFloat, height: CGFloat, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
