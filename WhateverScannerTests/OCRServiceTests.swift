import XCTest
import UIKit
@testable import WhateverScanner

/// Unit tests for `OCRService`. Only the deterministic code paths are covered:
/// the empty-input guard and a blank (text-free) image, both of which produce
/// stable results. The text-extraction heuristics themselves are `private` and
/// depend on Vision's real OCR output, so they aren't directly unit-testable
/// without making them internal or mocking Vision's recognition results.
final class OCRServiceTests: XCTestCase {

    func testAnalyzeDocumentWithNoImagesReturnsNilFields() async {
        let info = await OCRService.shared.analyzeDocument(images: [])
        XCTAssertNil(info.suggestedName)
        XCTAssertNil(info.documentDate)
    }

    func testAnalyzeDocumentWithBlankImageReturnsNilFields() async {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let blankImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }

        let info = await OCRService.shared.analyzeDocument(images: [blankImage])
        XCTAssertNil(info.suggestedName)
        XCTAssertNil(info.documentDate)
    }
}
