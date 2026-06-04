import Foundation

/// A configured WebDAV server.
/// Server metadata is persisted in UserDefaults as JSON.
/// The password is **not** included in the JSON; it is stored separately
/// in the iOS Keychain via `KeychainService`.
struct WebDAVServer: Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var username: String
    /// Loaded from the Keychain at runtime; never written to UserDefaults.
    var password: String

    /// Creates a new WebDAV server configuration.
    /// - Parameters:
    ///   - id: Unique identifier for the server. Defaults to a new UUID.
    ///   - name: A user-facing display name.
    ///   - url: The WebDAV endpoint URL.
    ///   - username: The authentication username.
    ///   - password: The authentication password (stored in Keychain, not in JSON).
    init(id: UUID = UUID(), name: String, url: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
    }
}

// MARK: - Codable (password excluded)

extension WebDAVServer: Codable {
    /// Only metadata fields are encoded/decoded. Passwords live in the Keychain.
    enum CodingKeys: String, CodingKey {
        case id, name, url, username
    }

    /// Decodes a server from JSON. The password field is intentionally excluded and set to empty;
    /// it is restored from the Keychain by `AppSettings`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,   forKey: .id)
        name     = try c.decode(String.self, forKey: .name)
        url      = try c.decode(String.self, forKey: .url)
        username = try c.decode(String.self, forKey: .username)
        password = "" // Restored from Keychain by AppSettings
    }

    /// Encodes the server to JSON, deliberately omitting the password.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(url,      forKey: .url)
        try c.encode(username, forKey: .username)
    }
}
