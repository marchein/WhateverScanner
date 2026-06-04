import XCTest
@testable import WhateverScanner

/// Unit tests for the WhateverScanner app covering WebDAV server model,
/// app settings server management, upload targets, and PDF service functionality.
final class WhateverScannerTests: XCTestCase {

    // MARK: - WebDAVServer

    func testWebDAVServerCreation() {
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

    func testWebDAVServerEquality() {
        let id = UUID()
        let a = WebDAVServer(id: id, name: "A", url: "https://a.example.com/", username: "u", password: "p")
        let b = WebDAVServer(id: id, name: "A", url: "https://a.example.com/", username: "u", password: "p")
        XCTAssertEqual(a, b)
    }

    func testWebDAVServerCodable() throws {
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

    func testWebDAVServerPasswordNotInJSON() throws {
        let server = WebDAVServer(name: "T", url: "https://t.example.com/", username: "u", password: "secret")
        let data = try JSONEncoder().encode(server)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("secret"), "Password must not appear in serialised JSON")
    }

    // MARK: - AppSettings – server management

    func testAddServerIncreasesCount() {
        let settings = makeSettings()
        XCTAssertEqual(settings.servers.count, 0)

        settings.addServer(makeServer(name: "S1"))
        XCTAssertEqual(settings.servers.count, 1)
    }

    func testFirstAddedServerBecomesDefault() {
        let settings = makeSettings()
        let server = makeServer(name: "S1")
        settings.addServer(server)
        XCTAssertEqual(settings.defaultServerId, server.id)
    }

    func testSecondServerDoesNotOverrideDefault() {
        let settings = makeSettings()
        let s1 = makeServer(name: "S1")
        let s2 = makeServer(name: "S2")
        settings.addServer(s1)
        settings.addServer(s2)
        XCTAssertEqual(settings.defaultServerId, s1.id)
    }

    func testUpdateServer() {
        let settings = makeSettings()
        let server = makeServer(name: "Original")
        settings.addServer(server)

        var updated = server
        updated.name = "Updated"
        settings.updateServer(updated)

        XCTAssertEqual(settings.servers.first?.name, "Updated")
    }

    func testRemoveServer() {
        let settings = makeSettings()
        settings.addServer(makeServer(name: "S1"))
        settings.addServer(makeServer(name: "S2"))
        settings.removeServer(at: IndexSet(integer: 0))
        XCTAssertEqual(settings.servers.count, 1)
    }

    func testRemovingDefaultServerReassignsDefault() {
        let settings = makeSettings()
        let s1 = makeServer(name: "S1")
        let s2 = makeServer(name: "S2")
        settings.addServer(s1)
        settings.addServer(s2)
        XCTAssertEqual(settings.defaultServerId, s1.id)

        settings.removeServer(at: IndexSet(integer: 0))
        XCTAssertEqual(settings.defaultServerId, s2.id)
    }

    func testSetDefaultServer() {
        let settings = makeSettings()
        let s1 = makeServer(name: "S1")
        let s2 = makeServer(name: "S2")
        settings.addServer(s1)
        settings.addServer(s2)
        settings.setDefaultServer(s2)
        XCTAssertEqual(settings.defaultServerId, s2.id)
    }

    // MARK: - AppSettings – upload targets

    func testUploadTargetsAllServers() {
        let settings = makeSettings()
        settings.uploadToAllServers = true
        settings.addServer(makeServer(name: "S1"))
        settings.addServer(makeServer(name: "S2"))
        XCTAssertEqual(settings.uploadTargets.count, 2)
    }

    func testUploadTargetsDefaultOnly() {
        let settings = makeSettings()
        settings.uploadToAllServers = false
        let s1 = makeServer(name: "S1")
        let s2 = makeServer(name: "S2")
        settings.addServer(s1)
        settings.addServer(s2)
        settings.setDefaultServer(s2)

        let targets = settings.uploadTargets
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.id, s2.id)
    }

    // MARK: - PDFService

    func testPDFFilenameFormat() {
        let filename = PDFService.shared.generateFilename()
        XCTAssertTrue(filename.hasPrefix("Scan_"), "Expected filename to start with 'Scan_'")
        XCTAssertTrue(filename.hasSuffix(".pdf"), "Expected filename to end with '.pdf'")
    }

    func testCreatePDFFromEmptyArrayReturnsNil() {
        XCTAssertNil(PDFService.shared.createPDF(from: []))
    }

    // MARK: - Helpers

    private func makeSettings() -> AppSettings {
        let s = AppSettings()
        s.servers = []
        s.defaultServerId = nil
        s.uploadToAllServers = false
        return s
    }

    private func makeServer(name: String) -> WebDAVServer {
        WebDAVServer(
            name: name,
            url: "https://\(name.lowercased()).example.com/",
            username: "user",
            password: "pass"
        )
    }
}
