import XCTest
@testable import WhateverScanner

/// Unit tests for the `WebDAVServer` model, covering creation, equality, and its
/// custom Codable implementation which deliberately excludes the password.
final class WebDAVServerTests: XCTestCase {

    func testCreation() {
        let server = WebDAVServer(
            name: "My Cloud",
            url: "https://cloud.example.com/dav/",
            username: "alice",
            password: "s3cr3t"
        )
        XCTAssertEqual(server.name, "My Cloud")
        XCTAssertEqual(server.url, "https://cloud.example.com/dav/")
        XCTAssertEqual(server.username, "alice")
    }

    func testEquality() {
        let id = UUID()
        let a = WebDAVServer(id: id, name: "A", url: "https://a.example.com/", username: "u", password: "p")
        let b = WebDAVServer(id: id, name: "A", url: "https://a.example.com/", username: "u", password: "p")
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let server = WebDAVServer(name: "Test", url: "https://t.example.com/", username: "u", password: "p")
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(WebDAVServer.self, from: data)
        // Metadata survives the round-trip
        XCTAssertEqual(decoded.id,       server.id)
        XCTAssertEqual(decoded.name,     server.name)
        XCTAssertEqual(decoded.url,      server.url)
        XCTAssertEqual(decoded.username, server.username)
        // Password is NOT stored in JSON — it arrives empty from the decoder
        XCTAssertEqual(decoded.password, "")
    }

    func testPasswordNotInJSON() throws {
        let server = WebDAVServer(name: "T", url: "https://t.example.com/", username: "u", password: "secret")
        let data = try JSONEncoder().encode(server)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("secret"), "Password must not appear in serialised JSON")
    }
}
