import Foundation
import Combine

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

    var defaultServer: WebDAVServer? {
        guard let id = defaultServerId else { return servers.first }
        return servers.first { $0.id == id }
    }

    var uploadTargets: [WebDAVServer] {
        if uploadToAllServers {
            return servers
        } else if let server = defaultServer {
            return [server]
        }
        return servers
    }

    // MARK: - Init

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

    func addServer(_ server: WebDAVServer) {
        savePasswordToKeychain(for: server)
        servers.append(server)
        if defaultServerId == nil {
            defaultServerId = server.id
        }
    }

    func updateServer(_ server: WebDAVServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            savePasswordToKeychain(for: server)
            servers[index] = server
        }
    }

    func removeServer(at offsets: IndexSet) {
        let removedIds = offsets.map { servers[$0].id }
        removedIds.forEach { KeychainService.delete(forKey: $0.uuidString) }
        servers.remove(atOffsets: offsets)
        if removedIds.contains(where: { $0 == defaultServerId }) {
            defaultServerId = servers.first?.id
        }
    }

    func setDefaultServer(_ server: WebDAVServer) {
        defaultServerId = server.id
    }

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

    private func savePasswordToKeychain(for server: WebDAVServer) {
        try? KeychainService.save(password: server.password, forKey: server.id.uuidString)
    }

    // MARK: - Keys

    private enum Keys {
        static let isSetupComplete  = "isSetupComplete"
        static let servers          = "servers"
        static let defaultServerId  = "defaultServerId"
        static let autoStartScan    = "autoStartScan"
        static let uploadToAllServers = "uploadToAllServers"
    }
}
