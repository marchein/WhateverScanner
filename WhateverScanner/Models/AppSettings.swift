import Foundation
import Combine

/// Observable settings model that manages app-wide configuration and the list
/// of WebDAV servers. Server metadata is persisted to UserDefaults while passwords
/// are stored securely in the iOS Keychain via `KeychainService`.
class AppSettings: ObservableObject {

    // MARK: - Persisted Properties

    @Published var isSetupComplete: Bool {
        didSet { UserDefaults.standard.set(isSetupComplete, forKey: Keys.isSetupComplete) }
    }

    @Published var servers: [WebDAVServer] {
        didSet { persistServers() }
    }

    @Published var defaultServerId: UUID? {
        didSet {
            UserDefaults.standard.set(defaultServerId?.uuidString, forKey: Keys.defaultServerId)
        }
    }

    /// When true the scanner opens automatically on every app launch.
    @Published var autoStartScan: Bool {
        didSet { UserDefaults.standard.set(autoStartScan, forKey: Keys.autoStartScan) }
    }

    /// When true every scan is automatically uploaded to the configured WebDAV server(s).
    @Published var autoUploadToWebDAV: Bool {
        didSet { UserDefaults.standard.set(autoUploadToWebDAV, forKey: Keys.autoUploadToWebDAV) }
    }

    /// When true every scan is uploaded to all configured servers.
    /// When false only the default server receives the upload.
    @Published var uploadToAllServers: Bool {
        didSet { UserDefaults.standard.set(uploadToAllServers, forKey: Keys.uploadToAllServers) }
    }

    /// When true every scan is automatically saved as images to the Photos library.
    @Published var autoSaveToPhotos: Bool {
        didSet { UserDefaults.standard.set(autoSaveToPhotos, forKey: Keys.autoSaveToPhotos) }
    }

    /// When true every scan is automatically saved as a PDF to the selected Files app folder.
    @Published var autoSaveToFiles: Bool {
        didSet { UserDefaults.standard.set(autoSaveToFiles, forKey: Keys.autoSaveToFiles) }
    }

    /// Security-scoped bookmark for the folder selected to receive scanned PDFs.
    @Published var filesFolderBookmark: Data? {
        didSet { UserDefaults.standard.set(filesFolderBookmark, forKey: Keys.filesFolderBookmark) }
    }

    /// A user-facing display name for the selected Files app folder.
    @Published var filesFolderName: String? {
        didSet { UserDefaults.standard.set(filesFolderName, forKey: Keys.filesFolderName) }
    }

    /// When true every scan is automatically uploaded to the configured SMB share(s).
    @Published var autoUploadToSMB: Bool {
        didSet { UserDefaults.standard.set(autoUploadToSMB, forKey: Keys.autoUploadToSMB) }
    }

    @Published var smbServers: [SMBServer] {
        didSet { persistSMBServers() }
    }

    @Published var defaultSMBServerId: UUID? {
        didSet {
            UserDefaults.standard.set(defaultSMBServerId?.uuidString, forKey: Keys.defaultSMBServerId)
        }
    }

    /// When true every scan is uploaded to all configured SMB shares.
    /// When false only the default SMB share receives the upload.
    @Published var uploadToAllSMBServers: Bool {
        didSet { UserDefaults.standard.set(uploadToAllSMBServers, forKey: Keys.uploadToAllSMBServers) }
    }

    // MARK: - Derived Properties

    /// The server currently selected as the default upload destination.
    /// Falls back to the first server if no explicit default is set.
    var defaultServer: WebDAVServer? {
        guard let id = defaultServerId else { return servers.first }
        return servers.first { $0.id == id }
    }

    /// The list of servers that should receive uploaded scans based on current settings.
    var uploadTargets: [WebDAVServer] {
        if uploadToAllServers {
            return servers
        } else if let server = defaultServer {
            return [server]
        }
        return servers
    }

    /// The SMB server currently selected as the default upload destination.
    /// Falls back to the first server if no explicit default is set.
    var defaultSMBServer: SMBServer? {
        guard let id = defaultSMBServerId else { return smbServers.first }
        return smbServers.first { $0.id == id }
    }

    /// The list of SMB servers that should receive uploaded scans based on current settings.
    var smbUploadTargets: [SMBServer] {
        if uploadToAllSMBServers {
            return smbServers
        } else if let server = defaultSMBServer {
            return [server]
        }
        return smbServers
    }

    // MARK: - Init

    /// Initializes settings by reading persisted values from UserDefaults and restoring
    /// server passwords from the Keychain.
    init() {
        let defaults = UserDefaults.standard
        self.isSetupComplete  = defaults.bool(forKey: Keys.isSetupComplete)
        self.autoStartScan    = defaults.bool(forKey: Keys.autoStartScan)
        // Defaults to true so upgrading users keep their existing WebDAV upload behavior.
        self.autoUploadToWebDAV = defaults.object(forKey: Keys.autoUploadToWebDAV) as? Bool ?? true
        self.uploadToAllServers = defaults.bool(forKey: Keys.uploadToAllServers)
        self.autoSaveToPhotos = defaults.bool(forKey: Keys.autoSaveToPhotos)
        self.autoSaveToFiles  = defaults.bool(forKey: Keys.autoSaveToFiles)
        self.filesFolderBookmark = defaults.data(forKey: Keys.filesFolderBookmark)
        self.filesFolderName  = defaults.string(forKey: Keys.filesFolderName)
        self.autoUploadToSMB  = defaults.bool(forKey: Keys.autoUploadToSMB)
        self.uploadToAllSMBServers = defaults.bool(forKey: Keys.uploadToAllSMBServers)

        if let uuidString = defaults.string(forKey: Keys.defaultServerId),
           let uuid = UUID(uuidString: uuidString) {
            self.defaultServerId = uuid
        } else {
            self.defaultServerId = nil
        }

        if let uuidString = defaults.string(forKey: Keys.defaultSMBServerId),
           let uuid = UUID(uuidString: uuidString) {
            self.defaultSMBServerId = uuid
        } else {
            self.defaultSMBServerId = nil
        }

        self.servers = AppSettings.loadServers()
        self.smbServers = AppSettings.loadSMBServers()
    }

    // MARK: - Server Management

    /// Adds a new server, saves its password to the Keychain, and sets it as default if none exists.
    /// - Parameter server: The server to add.
    func addServer(_ server: WebDAVServer) {
        savePasswordToKeychain(for: server)
        servers.append(server)
        if defaultServerId == nil {
            defaultServerId = server.id
        }
    }

    /// Updates an existing server's configuration and saves its password to the Keychain.
    /// - Parameter server: The server with updated values. Matched by `id`.
    func updateServer(_ server: WebDAVServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            savePasswordToKeychain(for: server)
            servers[index] = server
        }
    }

    /// Removes servers at the specified indices, deleting their Keychain entries
    /// and reassigning the default server if needed.
    /// - Parameter offsets: The index set of servers to remove.
    func removeServer(at offsets: IndexSet) {
        let removedIds = offsets.map { servers[$0].id }
        removedIds.forEach { KeychainService.delete(forKey: $0.uuidString) }
        servers.remove(atOffsets: offsets)
        if removedIds.contains(where: { $0 == defaultServerId }) {
            defaultServerId = servers.first?.id
        }
    }

    /// Sets the given server as the default upload destination.
    /// - Parameter server: The server to mark as default.
    func setDefaultServer(_ server: WebDAVServer) {
        defaultServerId = server.id
    }

    /// Marks the initial setup as complete so the app skips onboarding on future launches.
    func completeSetup() {
        isSetupComplete = true
    }

    // MARK: - SMB Server Management

    /// Adds a new SMB server, saves its password to the Keychain, and sets it as default if none exists.
    /// - Parameter server: The server to add.
    func addSMBServer(_ server: SMBServer) {
        saveSMBPasswordToKeychain(for: server)
        smbServers.append(server)
        if defaultSMBServerId == nil {
            defaultSMBServerId = server.id
        }
    }

    /// Updates an existing SMB server's configuration and saves its password to the Keychain.
    /// - Parameter server: The server with updated values. Matched by `id`.
    func updateSMBServer(_ server: SMBServer) {
        if let index = smbServers.firstIndex(where: { $0.id == server.id }) {
            saveSMBPasswordToKeychain(for: server)
            smbServers[index] = server
        }
    }

    /// Removes SMB servers at the specified indices, deleting their Keychain entries
    /// and reassigning the default server if needed.
    /// - Parameter offsets: The index set of servers to remove.
    func removeSMBServer(at offsets: IndexSet) {
        let removedIds = offsets.map { smbServers[$0].id }
        removedIds.forEach { KeychainService.delete(forKey: "smb-" + $0.uuidString) }
        smbServers.remove(atOffsets: offsets)
        if removedIds.contains(where: { $0 == defaultSMBServerId }) {
            defaultSMBServerId = smbServers.first?.id
        }
    }

    /// Sets the given server as the default SMB upload destination.
    /// - Parameter server: The server to mark as default.
    func setDefaultSMBServer(_ server: SMBServer) {
        defaultSMBServerId = server.id
    }

    // MARK: - Persistence

    /// Persist server metadata to UserDefaults (passwords stay in Keychain).
    private func persistServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: Keys.servers)
        }
    }

    /// Load server metadata and restore passwords from Keychain.
    private static func loadServers() -> [WebDAVServer] {
        guard let data = UserDefaults.standard.data(forKey: Keys.servers),
              var decoded = try? JSONDecoder().decode([WebDAVServer].self, from: data) else {
            return []
        }
        for i in decoded.indices {
            decoded[i].password = KeychainService.retrieve(forKey: decoded[i].id.uuidString) ?? ""
        }
        return decoded
    }

    /// Saves the server's password to the iOS Keychain.
    /// - Parameter server: The server whose password should be stored.
    private func savePasswordToKeychain(for server: WebDAVServer) {
        try? KeychainService.save(password: server.password, forKey: server.id.uuidString)
    }

    /// Persist SMB server metadata to UserDefaults (passwords stay in Keychain).
    private func persistSMBServers() {
        if let data = try? JSONEncoder().encode(smbServers) {
            UserDefaults.standard.set(data, forKey: Keys.smbServers)
        }
    }

    /// Load SMB server metadata and restore passwords from Keychain.
    private static func loadSMBServers() -> [SMBServer] {
        guard let data = UserDefaults.standard.data(forKey: Keys.smbServers),
              var decoded = try? JSONDecoder().decode([SMBServer].self, from: data) else {
            return []
        }
        for i in decoded.indices {
            decoded[i].password = KeychainService.retrieve(forKey: "smb-" + decoded[i].id.uuidString) ?? ""
        }
        return decoded
    }

    /// Saves the SMB server's password to the iOS Keychain.
    /// - Parameter server: The server whose password should be stored.
    private func saveSMBPasswordToKeychain(for server: SMBServer) {
        try? KeychainService.save(password: server.password, forKey: "smb-" + server.id.uuidString)
    }

    // MARK: - Keys

    /// UserDefaults keys used for persisting settings.
    private enum Keys {
        static let isSetupComplete  = "isSetupComplete"
        static let servers          = "servers"
        static let defaultServerId  = "defaultServerId"
        static let autoStartScan    = "autoStartScan"
        static let autoUploadToWebDAV = "autoUploadToWebDAV"
        static let uploadToAllServers = "uploadToAllServers"
        static let autoSaveToPhotos = "autoSaveToPhotos"
        static let autoSaveToFiles  = "autoSaveToFiles"
        static let filesFolderBookmark = "filesFolderBookmark"
        static let filesFolderName  = "filesFolderName"
        static let autoUploadToSMB  = "autoUploadToSMB"
        static let smbServers       = "smbServers"
        static let defaultSMBServerId = "defaultSMBServerId"
        static let uploadToAllSMBServers = "uploadToAllSMBServers"
    }
}
