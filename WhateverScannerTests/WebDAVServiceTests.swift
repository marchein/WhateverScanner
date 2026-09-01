import XCTest
@testable import WhateverScanner

/// Unit tests for `WebDAVService`. Covers the deterministic, network-free error
/// paths (invalid URLs) and the `WebDAVError` descriptions. Actual network requests
/// are not exercised here since the service has no injectable transport.
final class WebDAVServiceTests: XCTestCase {

    func testUploadWithInvalidURLThrowsInvalidURL() async {
        // A raw, unencoded space makes the string unparsable by `URL(string:)`.
        let server = WebDAVServer(name: "Bad", url: "https://exa mple.com/", username: "u", password: "p")
        do {
            try await WebDAVService.shared.upload(data: Data("x".utf8), filename: "f.pdf", to: server)
            XCTFail("Expected an error to be thrown")
        } catch WebDAVError.invalidURL {
            // expected
        } catch {
            XCTFail("Expected invalidURL, got \(error)")
        }
    }

    func testTestConnectionWithInvalidURLThrowsInvalidURL() async {
        let server = WebDAVServer(name: "Bad", url: "https://exa mple.com/", username: "u", password: "p")
        do {
            try await WebDAVService.shared.testConnection(to: server)
            XCTFail("Expected an error to be thrown")
        } catch WebDAVError.invalidURL {
            // expected
        } catch {
            XCTFail("Expected invalidURL, got \(error)")
        }
    }

    // MARK: - WebDAVError descriptions

    func testInvalidURLErrorDescription() {
        XCTAssertNotNil(WebDAVError.invalidURL.errorDescription)
    }

    func testAuthenticationFailedErrorDescription() {
        XCTAssertNotNil(WebDAVError.authenticationFailed.errorDescription)
    }

    func testServerErrorDescriptionIncludesStatusCode() {
        let description = WebDAVError.serverError(500).errorDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("500"))
    }

    func testNetworkErrorDescriptionForwardsUnderlyingMessage() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "offline"])
        XCTAssertEqual(WebDAVError.networkError(underlying).errorDescription, "offline")
    }
}
