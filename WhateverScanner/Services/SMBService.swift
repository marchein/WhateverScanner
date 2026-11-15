import Foundation
import AMSMB2

// MARK: - Errors

/// Errors that can occur during SMB operations.
enum SMBError: LocalizedError {
    /// The server URL could not be constructed from the host name.
    case invalidHost
    /// A network or protocol-level error occurred while connecting or transferring data.
    case connectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return String(localized: "The SMB server host is invalid.")
        case .connectionFailed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Service

/// Thread-safe actor responsible for communicating with SMB (Samba) shares.
/// Wraps the AMSMB2 library to upload files and test connectivity.
actor SMBService {
    /// Shared singleton instance.
    static let shared = SMBService()

    private init() {}

    /// Uploads data to an SMB share as a file.
    /// - Parameters:
    ///   - data: The file data to upload.
    ///   - filename: The destination filename on the share.
    ///   - server: The target SMB server configuration.
    /// - Throws: `SMBError` if the host is invalid or the connection/transfer fails.
    func upload(data: Data, filename: String, to server: SMBServer) async throws {
        let client = try makeClient(for: server)
        do {
            try await client.connectShare(name: server.share)
        } catch {
            throw SMBError.connectionFailed(error)
        }

        do {
            let directory = Self.normalizedDirectory(server.path)
            if !directory.isEmpty {
                await createDirectoryIfNeeded(directory, using: client)
            }
            let remotePath = directory.isEmpty ? filename : "\(directory)/\(filename)"
            try await client.write(data: data, toPath: remotePath, progress: nil)
        } catch {
            try? await client.disconnectShare()
            throw SMBError.connectionFailed(error)
        }
        try? await client.disconnectShare()
    }

    /// Tests connectivity and authentication against an SMB share.
    /// - Parameter server: The server configuration to test.
    /// - Throws: `SMBError` if the host is invalid or the connection fails.
    func testConnection(to server: SMBServer) async throws {
        let client = try makeClient(for: server)
        do {
            try await client.connectShare(name: server.share)
            try await client.disconnectShare()
        } catch {
            throw SMBError.connectionFailed(error)
        }
    }

    /// Normalizes a user-entered sub-path within a share: trims whitespace around
    /// the whole path, removes leading/trailing/duplicate slashes and converts
    /// backslashes to forward slashes. Whitespace inside folder names is preserved
    /// (e.g. `"Scans/ Inbox"` stays `"Scans/ Inbox"`), so existing folders are hit exactly.
    /// - Parameter path: The configured path (may be empty).
    /// - Returns: A path like `"Scans/2024"`, or an empty string for the share root.
    static func normalizedDirectory(_ path: String) -> String {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")
    }

    /// Creates every missing component of `directory` on the connected share,
    /// so a configured sub-folder doesn't have to exist up front.
    /// Errors are ignored here (most commonly "already exists"); if the folder
    /// really can't be created, the subsequent write reports a meaningful error.
    private func createDirectoryIfNeeded(_ directory: String, using client: SMB2Manager) async {
        var current = ""
        for component in directory.split(separator: "/") {
            current = current.isEmpty ? String(component) : "\(current)/\(component)"
            if (try? await client.attributesOfItem(atPath: current)) != nil {
                continue
            }
            do {
                try await client.createDirectory(atPath: current)
            } catch {
                Log.export.debug("SMB createDirectory failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    // MARK: - Helpers

    /// Builds an `SMB2Manager` client for the given server configuration.
    private func makeClient(for server: SMBServer) throws -> SMB2Manager {
        let host = server.host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "smb://", with: "", options: [.caseInsensitive, .anchored])
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !host.isEmpty,
              !host.contains(" "),
              let url = URL(string: "smb://\(host)") else {
            throw SMBError.invalidHost
        }
        let credential = URLCredential(user: server.username, password: server.password, persistence: .forSession)
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBError.invalidHost
        }
        // The library default is 60 s, which feels like a hang when the NAS is
        // offline or the device isn't on the local network.
        client.timeout = 20
        return client
    }
}
