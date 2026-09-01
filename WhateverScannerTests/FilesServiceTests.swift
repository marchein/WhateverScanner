import XCTest
@testable import WhateverScanner

/// Unit tests for `FilesService`, covering default-folder saves, bookmark resolution
/// failures, and the `FilesServiceError` descriptions.
final class FilesServiceTests: XCTestCase {

    func testDefaultFolderURLIsDocumentsDirectory() {
        let expected = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        XCTAssertEqual(FilesService.defaultFolderURL, expected)
    }

    func testSaveWithoutBookmarkWritesToDefaultFolder() throws {
        let filename = "FilesServiceTest_\(UUID().uuidString).pdf"
        let data = Data("hello".utf8)
        defer {
            try? FileManager.default.removeItem(
                at: FilesService.defaultFolderURL.appendingPathComponent(filename)
            )
        }

        try FilesService.save(data: data, filename: filename, bookmark: nil)

        let savedURL = FilesService.defaultFolderURL.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(try Data(contentsOf: savedURL), data)
    }

    func testResolveFolderWithInvalidBookmarkThrows() {
        let garbage = Data("not-a-real-bookmark".utf8)
        XCTAssertThrowsError(try FilesService.resolveFolder(from: garbage)) { error in
            guard case FilesServiceError.bookmarkResolutionFailed = error else {
                return XCTFail("Expected bookmarkResolutionFailed, got \(error)")
            }
        }
    }

    func testSaveWithInvalidBookmarkThrowsBookmarkResolutionFailed() {
        let garbage = Data("not-a-real-bookmark".utf8)
        XCTAssertThrowsError(
            try FilesService.save(data: Data("x".utf8), filename: "f.pdf", bookmark: garbage)
        ) { error in
            guard case FilesServiceError.bookmarkResolutionFailed = error else {
                return XCTFail("Expected bookmarkResolutionFailed, got \(error)")
            }
        }
    }

    // MARK: - FilesServiceError descriptions

    func testAccessDeniedErrorDescription() {
        XCTAssertNotNil(FilesServiceError.accessDenied.errorDescription)
    }

    func testBookmarkResolutionFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let description = FilesServiceError.bookmarkResolutionFailed(underlying).errorDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("boom"))
    }

    func testWriteFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        XCTAssertEqual(FilesServiceError.writeFailed(underlying).errorDescription, "disk full")
    }
}
