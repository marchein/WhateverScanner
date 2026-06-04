import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing per-server passwords.
enum KeychainService {

    /// The Keychain service identifier used for all password entries.
    private static let service = "com.marchein.WhateverScanner"

    /// Saves or updates a password in the Keychain for the given key.
    /// - Parameters:
    ///   - password: The password string to store.
    ///   - key: The unique key to associate with the password (typically a server's UUID string).
    /// - Throws: `KeychainError.saveFailed` if the Keychain operation fails.
    static func save(password: String, forKey key: String) throws {
        guard let data = password.data(using: .utf8) else { return }

        let baseQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        // Try to update an existing item first.
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — add it.
            var addQuery = baseQuery
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    /// Retrieves the password for the given key from the Keychain.
    /// - Parameter key: The key to look up (typically a server's UUID string).
    /// - Returns: The stored password string, or `nil` if no entry was found.
    static func retrieve(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    /// Deletes the password for the given key from the Keychain.
    /// - Parameter key: The key whose entry should be removed.
    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Error

    /// Errors that can occur during Keychain operations.
    enum KeychainError: Error, LocalizedError {
        /// A save or update operation failed with the given OS status code.
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain (OSStatus \(status))."
            }
        }
    }
}
