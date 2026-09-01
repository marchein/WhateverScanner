import XCTest
@testable import WhateverScanner

/// Unit tests for `AppSettings`, covering WebDAV and SMB server management,
/// derived upload-target lists, the Files/Photos auto-save flags, and setup
/// completion.
final class AppSettingsTests: XCTestCase {

    // MARK: - WebDAV server management

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

    // MARK: - Derived WebDAV upload targets

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

    // MARK: - SMB server management

    func testAddSMBServerIncreasesCount() {
        let settings = makeSettings()
        XCTAssertEqual(settings.smbServers.count, 0)

        settings.addSMBServer(makeSMBServer(name: "S1"))
        XCTAssertEqual(settings.smbServers.count, 1)
    }

    func testFirstAddedSMBServerBecomesDefault() {
        let settings = makeSettings()
        let server = makeSMBServer(name: "S1")
        settings.addSMBServer(server)
        XCTAssertEqual(settings.defaultSMBServerId, server.id)
    }

    func testSecondSMBServerDoesNotOverrideDefault() {
        let settings = makeSettings()
        let s1 = makeSMBServer(name: "S1")
        let s2 = makeSMBServer(name: "S2")
        settings.addSMBServer(s1)
        settings.addSMBServer(s2)
        XCTAssertEqual(settings.defaultSMBServerId, s1.id)
    }

    func testUpdateSMBServer() {
        let settings = makeSettings()
        let server = makeSMBServer(name: "Original")
        settings.addSMBServer(server)

        var updated = server
        updated.name = "Updated"
        settings.updateSMBServer(updated)

        XCTAssertEqual(settings.smbServers.first?.name, "Updated")
    }

    func testRemoveSMBServer() {
        let settings = makeSettings()
        settings.addSMBServer(makeSMBServer(name: "S1"))
        settings.addSMBServer(makeSMBServer(name: "S2"))
        settings.removeSMBServer(at: IndexSet(integer: 0))
        XCTAssertEqual(settings.smbServers.count, 1)
    }

    func testRemovingDefaultSMBServerReassignsDefault() {
        let settings = makeSettings()
        let s1 = makeSMBServer(name: "S1")
        let s2 = makeSMBServer(name: "S2")
        settings.addSMBServer(s1)
        settings.addSMBServer(s2)

        settings.removeSMBServer(at: IndexSet(integer: 0))
        XCTAssertEqual(settings.defaultSMBServerId, s2.id)
    }

    func testSetDefaultSMBServer() {
        let settings = makeSettings()
        let s1 = makeSMBServer(name: "S1")
        let s2 = makeSMBServer(name: "S2")
        settings.addSMBServer(s1)
        settings.addSMBServer(s2)
        settings.setDefaultSMBServer(s2)
        XCTAssertEqual(settings.defaultSMBServerId, s2.id)
    }

    // MARK: - Derived SMB upload targets

    func testSMBUploadTargetsAllServers() {
        let settings = makeSettings()
        settings.uploadToAllSMBServers = true
        settings.addSMBServer(makeSMBServer(name: "S1"))
        settings.addSMBServer(makeSMBServer(name: "S2"))
        XCTAssertEqual(settings.smbUploadTargets.count, 2)
    }

    func testSMBUploadTargetsDefaultOnly() {
        let settings = makeSettings()
        settings.uploadToAllSMBServers = false
        let s1 = makeSMBServer(name: "S1")
        let s2 = makeSMBServer(name: "S2")
        settings.addSMBServer(s1)
        settings.addSMBServer(s2)
        settings.setDefaultSMBServer(s2)

        let targets = settings.smbUploadTargets
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.id, s2.id)
    }

    func testSMBUploadTargetsEmptyWhenNoServers() {
        let settings = makeSettings()
        XCTAssertTrue(settings.smbUploadTargets.isEmpty)
    }

    // MARK: - Auto-save flags

    func testAutoSaveToPhotosTogglePersistsOnInstance() {
        let settings = makeSettings()
        XCTAssertFalse(settings.autoSaveToPhotos)
        settings.autoSaveToPhotos = true
        XCTAssertTrue(settings.autoSaveToPhotos)
    }

    func testAutoSaveToFilesTogglePersistsOnInstance() {
        let settings = makeSettings()
        XCTAssertFalse(settings.autoSaveToFiles)
        settings.autoSaveToFiles = true
        XCTAssertTrue(settings.autoSaveToFiles)
    }

    func testFilesFolderNameAndBookmarkRoundTripThroughDefaults() {
        let settings = makeSettings()
        let bookmark = Data("bookmark".utf8)
        settings.filesFolderBookmark = bookmark
        settings.filesFolderName = "Scans"

        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.filesFolderBookmark, bookmark)
        XCTAssertEqual(reloaded.filesFolderName, "Scans")

        // cleanup
        settings.filesFolderBookmark = nil
        settings.filesFolderName = nil
    }

    // MARK: - Setup completion

    func testCompleteSetupMarksSetupComplete() {
        let settings = makeSettings()
        settings.isSetupComplete = false
        settings.completeSetup()
        XCTAssertTrue(settings.isSetupComplete)
    }

    // MARK: - Helpers

    private func makeSettings() -> AppSettings {
        let s = AppSettings()
        s.servers = []
        s.defaultServerId = nil
        s.uploadToAllServers = false
        s.smbServers = []
        s.defaultSMBServerId = nil
        s.uploadToAllSMBServers = false
        s.autoSaveToPhotos = false
        s.autoSaveToFiles = false
        return s
    }

    private func makeSMBServer(name: String) -> SMBServer {
        SMBServer(
            name: name,
            host: "\(name.lowercased()).local",
            share: "Scans",
            username: "user",
            password: "pass"
        )
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
