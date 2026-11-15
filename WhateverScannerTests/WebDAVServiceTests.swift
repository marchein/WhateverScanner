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

    // MARK: - URL handling

    func testUploadURLPercentEncodesFilename() throws {
        let server = WebDAVServer(name: "S", url: "https://example.com/dav/", username: "u", password: "p")
        let filename = "Müller GmbH - Rechnung #1 100%_2024-05-01_13-30-05.pdf"
        let url = try WebDAVService.uploadURL(for: server, filename: filename)
        XCTAssertEqual(url.host, "example.com")
        XCTAssertEqual(url.lastPathComponent, filename)
        XCTAssertNil(url.query)
        XCTAssertNil(url.fragment)
        XCTAssertTrue(url.path.hasPrefix("/dav/"))
    }

    func testUploadURLWithoutTrailingSlashStillAppendsComponent() throws {
        let server = WebDAVServer(name: "S", url: "https://example.com/dav", username: "u", password: "p")
        let url = try WebDAVService.uploadURL(for: server, filename: "a.pdf")
        XCTAssertEqual(url.path, "/dav/a.pdf")
    }

    func testValidatedBaseURLRejectsNonHTTPSchemes() {
        XCTAssertNil(WebDAVService.validatedBaseURL("ftp://example.com/"))
        XCTAssertNil(WebDAVService.validatedBaseURL("example.com/dav/"))
        XCTAssertNil(WebDAVService.validatedBaseURL(""))
    }

    func testValidatedBaseURLAcceptsHTTPAndHTTPS() {
        XCTAssertNotNil(WebDAVService.validatedBaseURL("https://cloud.example.com/remote.php/dav/files/user/"))
        XCTAssertNotNil(WebDAVService.validatedBaseURL("http://192.168.1.10:8080/dav/"))
    }

    func testInsecureConnectionErrorDescription() {
        XCTAssertNotNil(WebDAVError.insecureConnection.errorDescription)
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
