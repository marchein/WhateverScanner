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

    /// When true every scan is uploaded to all configured servers.
    /// When false only the default server receives the upload.
    @Published var uploadToAllServers: Bool {
        didSet { UserDefaults.standard.set(uploadToAllServers, forKey: Keys.uploadToAllServers) }
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

    // MARK: - Init

    /// Initializes settings by reading persisted values from UserDefaults and restoring
    /// server passwords from the Keychain.
    init() {
        let defaults = UserDefaults.standard
        self.isSetupComplete  = defaults.bool(forKey: Keys.isSetupComplete)
        self.autoStartScan    = defaults.bool(forKey: Keys.autoStartScan)
        self.uploadToAllServers = defaults.bool(forKey: Keys.uploadToAllServers)

        if let uuidString = defaults.string(forKey: Keys.defaultServerId),
           let uuid = UUID(uuidString: uuidString) {
            self.defaultServerId = uuid
        } else {
            self.defaultServerId = nil
        }

        self.servers = AppSettings.loadServers()
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

    // MARK: - Keys

    /// UserDefaults keys used for persisting settings.
    private enum Keys {
        static let isSetupComplete  = "isSetupComplete"
        static let servers          = "servers"
        static let defaultServerId  = "defaultServerId"
        static let autoStartScan    = "autoStartScan"
        static let uploadToAllServers = "uploadToAllServers"
    }
}
