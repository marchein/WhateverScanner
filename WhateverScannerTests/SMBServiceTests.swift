import XCTest
@testable import WhateverScanner

/// Unit tests for `SMBService`. Covers the deterministic, network-free error
/// paths (invalid host) and the `SMBError` descriptions. Actual SMB connections
/// are not exercised here since that requires a live share.
final class SMBServiceTests: XCTestCase {

    func testUploadWithEmptyHostThrowsInvalidHost() async {
        let server = SMBServer(name: "Bad", host: "", share: "share", username: "u", password: "p")
        do {
            try await SMBService.shared.upload(data: Data("x".utf8), filename: "f.pdf", to: server)
            XCTFail("Expected an error to be thrown")
        } catch SMBError.invalidHost {
            // expected
        } catch {
            XCTFail("Expected invalidHost, got \(error)")
        }
    }

    func testTestConnectionWithEmptyHostThrowsInvalidHost() async {
        let server = SMBServer(name: "Bad", host: "   ", share: "share", username: "u", password: "p")
        do {
            try await SMBService.shared.testConnection(to: server)
            XCTFail("Expected an error to be thrown")
        } catch SMBError.invalidHost {
            // expected
        } catch {
            XCTFail("Expected invalidHost, got \(error)")
        }
    }

    // MARK: - SMBError descriptions

    func testInvalidHostErrorDescription() {
        XCTAssertNotNil(SMBError.invalidHost.errorDescription)
    }

    func testConnectionFailedErrorDescriptionForwardsUnderlyingMessage() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "unreachable"])
        XCTAssertEqual(SMBError.connectionFailed(underlying).errorDescription, "unreachable")
    }
}
