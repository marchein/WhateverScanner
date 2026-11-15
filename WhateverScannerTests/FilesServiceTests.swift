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

    func testSavingTwiceDoesNotOverwriteExistingFile() throws {
        let filename = "FilesServiceTest_\(UUID().uuidString).pdf"
        let folder = FilesService.defaultFolderURL
        let first = folder.appendingPathComponent(filename)
        let second = FilesService.uniqueFileURL(in: folder, filename: filename)
        XCTAssertEqual(first, second, "Without an existing file the original name is used")

        try FilesService.save(data: Data("one".utf8), filename: filename, bookmark: nil)
        let renamed = FilesService.uniqueFileURL(in: folder, filename: filename)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: renamed)
        }
        XCTAssertNotEqual(renamed, first)
        XCTAssertEqual(renamed.pathExtension, "pdf")

        try FilesService.save(data: Data("two".utf8), filename: filename, bookmark: nil)
        XCTAssertEqual(try Data(contentsOf: first), Data("one".utf8))
        XCTAssertEqual(try Data(contentsOf: renamed), Data("two".utf8))
    }

    func testUniqueFileURLKeepsSearchingPastManyCollisions() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let filename = "Scan.pdf"
        try Data().write(to: folder.appendingPathComponent(filename))
        for index in 2...1000 {
            try Data().write(to: folder.appendingPathComponent("Scan \(index).pdf"))
        }

        let url = FilesService.uniqueFileURL(in: folder, filename: filename)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "Scan 1001.pdf")
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
