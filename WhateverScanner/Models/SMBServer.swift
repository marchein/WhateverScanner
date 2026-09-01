import Foundation

/// A configured SMB (Samba) share.
/// Server metadata is persisted in UserDefaults as JSON.
/// The password is **not** included in the JSON; it is stored separately
/// in the iOS Keychain via `KeychainService`.
struct SMBServer: Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    /// The SMB server's hostname or IP address (without scheme or share name).
    var host: String
    /// The share name to connect to on the server.
    var share: String
    /// An optional path within the share to upload files to.
    var path: String
    var username: String
    /// Loaded from the Keychain at runtime; never written to UserDefaults.
    var password: String

    /// Creates a new SMB server configuration.
    /// - Parameters:
    ///   - id: Unique identifier for the server. Defaults to a new UUID.
    ///   - name: A user-facing display name.
    ///   - host: The SMB server's hostname or IP address.
    ///   - share: The share name to connect to.
    ///   - path: An optional path within the share to upload files to.
    ///   - username: The authentication username.
    ///   - password: The authentication password (stored in Keychain, not in JSON).
    init(id: UUID = UUID(), name: String, host: String, share: String, path: String = "", username: String, password: String) {
        self.id = id
        self.name = name
        self.host = host
        self.share = share
        self.path = path
        self.username = username
        self.password = password
    }
}

// MARK: - Codable (password excluded)

extension SMBServer: Codable {
    /// Only metadata fields are encoded/decoded. Passwords live in the Keychain.
    enum CodingKeys: String, CodingKey {
        case id, name, host, share, path, username
    }

    /// Decodes a server from JSON. The password field is intentionally excluded and set to empty;
    /// it is restored from the Keychain by `AppSettings`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,   forKey: .id)
        name     = try c.decode(String.self, forKey: .name)
        host     = try c.decode(String.self, forKey: .host)
        share    = try c.decode(String.self, forKey: .share)
        path     = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        username = try c.decode(String.self, forKey: .username)
        password = "" // Restored from Keychain by AppSettings
    }

    /// Encodes the server to JSON, deliberately omitting the password.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(host,     forKey: .host)
        try c.encode(share,    forKey: .share)
        try c.encode(path,     forKey: .path)
        try c.encode(username, forKey: .username)
    }
}
