import XCTest
@testable import WhateverScanner

/// Unit tests for the `SMBServer` model, covering creation, equality, and its
/// custom Codable implementation which deliberately excludes the password.
final class SMBServerTests: XCTestCase {

    func testCreationWithDefaultPath() {
        let server = SMBServer(name: "NAS", host: "192.168.1.10", share: "Scans", username: "alice", password: "s3cr3t")
        XCTAssertEqual(server.name, "NAS")
        XCTAssertEqual(server.host, "192.168.1.10")
        XCTAssertEqual(server.share, "Scans")
        XCTAssertEqual(server.path, "")
        XCTAssertEqual(server.username, "alice")
    }

    func testCreationWithExplicitPath() {
        let server = SMBServer(name: "NAS", host: "h", share: "s", path: "Documents/Scans", username: "u", password: "p")
        XCTAssertEqual(server.path, "Documents/Scans")
    }

    func testEquality() {
        let id = UUID()
        let a = SMBServer(id: id, name: "A", host: "h", share: "s", username: "u", password: "p")
        let b = SMBServer(id: id, name: "A", host: "h", share: "s", username: "u", password: "p")
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let server = SMBServer(name: "NAS", host: "h", share: "s", path: "sub", username: "u", password: "p")
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(SMBServer.self, from: data)

        XCTAssertEqual(decoded.id, server.id)
        XCTAssertEqual(decoded.name, server.name)
        XCTAssertEqual(decoded.host, server.host)
        XCTAssertEqual(decoded.share, server.share)
        XCTAssertEqual(decoded.path, server.path)
        XCTAssertEqual(decoded.username, server.username)
        // Password is NOT stored in JSON — it arrives empty from the decoder
        XCTAssertEqual(decoded.password, "")
    }

    func testDecodingMissingPathDefaultsToEmptyString() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"NAS","host":"h","share":"s","username":"u"}
        """
        let decoded = try JSONDecoder().decode(SMBServer.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.path, "")
    }

    func testPasswordNotInJSON() throws {
        let server = SMBServer(name: "NAS", host: "h", share: "s", username: "u", password: "secret")
        let data = try JSONEncoder().encode(server)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("secret"), "Password must not appear in serialised JSON")
    }
}
