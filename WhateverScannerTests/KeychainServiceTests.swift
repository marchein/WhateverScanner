import XCTest
@testable import WhateverScanner

/// Unit tests for `KeychainService`, covering the save/retrieve/delete round-trip
/// and update-in-place behaviour.
final class KeychainServiceTests: XCTestCase {

    private var testKey: String!

    override func setUp() {
        super.setUp()
        testKey = "test-\(UUID().uuidString)"
    }

    override func tearDown() {
        KeychainService.delete(forKey: testKey)
        super.tearDown()
    }

    func testSaveAndRetrieveRoundTrip() throws {
        try KeychainService.save(password: "s3cr3t", forKey: testKey)
        XCTAssertEqual(KeychainService.retrieve(forKey: testKey), "s3cr3t")
    }

    func testRetrieveMissingKeyReturnsNil() {
        XCTAssertNil(KeychainService.retrieve(forKey: "does-not-exist-\(UUID().uuidString)"))
    }

    func testSaveTwiceUpdatesExistingValue() throws {
        try KeychainService.save(password: "first", forKey: testKey)
        try KeychainService.save(password: "second", forKey: testKey)
        XCTAssertEqual(KeychainService.retrieve(forKey: testKey), "second")
    }

    func testDeleteRemovesValue() throws {
        try KeychainService.save(password: "s3cr3t", forKey: testKey)
        KeychainService.delete(forKey: testKey)
        XCTAssertNil(KeychainService.retrieve(forKey: testKey))
    }

    func testDeleteMissingKeyDoesNotThrow() {
        KeychainService.delete(forKey: "does-not-exist-\(UUID().uuidString)")
    }

    func testSaveFailedErrorDescription() {
        let error = KeychainService.KeychainError.saveFailed(errSecParam)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("\(errSecParam)"))
    }
}
