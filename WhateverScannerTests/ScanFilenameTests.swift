import XCTest
@testable import WhateverScanner

/// Unit tests for `ScanFilename`, which builds the filename for saved/uploaded scans.
final class ScanFilenameTests: XCTestCase {

    private let fixedDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2024
        components.month = 5
        components.day = 1
        components.hour = 13
        components.minute = 30
        components.second = 5
        return components.date!
    }()

    func testMakeUsesNameAndDate() {
        XCTAssertEqual(ScanFilename.make(name: "Invoice", date: fixedDate), "Invoice_2024-05-01_13-30-05.pdf")
    }

    func testMakeFallsBackToScanForEmptyName() {
        XCTAssertEqual(ScanFilename.make(name: "   ", date: fixedDate), "Scan_2024-05-01_13-30-05.pdf")
    }

    func testSanitizeReplacesInvalidCharacters() {
        XCTAssertEqual(ScanFilename.sanitize("A/B\\C:D*E?F\"G<H>I|J"), "A_B_C_D_E_F_G_H_I_J")
    }

    func testSanitizeRemovesNewlinesAndControlCharacters() {
        XCTAssertFalse(ScanFilename.sanitize("Line1\nLine2\tTab").contains("\n"))
        XCTAssertFalse(ScanFilename.sanitize("Line1\nLine2\tTab").contains("\t"))
    }

    func testSanitizeStripsLeadingAndTrailingDots() {
        XCTAssertEqual(ScanFilename.sanitize("..hidden."), "hidden")
    }

    func testSanitizeLimitsLength() {
        let long = String(repeating: "a", count: 500)
        XCTAssertEqual(ScanFilename.sanitize(long).count, ScanFilename.maxNameLength)
    }

    func testSanitizeKeepsUmlautsAndSpaces() {
        XCTAssertEqual(ScanFilename.sanitize("Müller GmbH - Rechnung"), "Müller GmbH - Rechnung")
    }
}
