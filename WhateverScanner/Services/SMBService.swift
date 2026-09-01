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
            defer { Task { try? await client.disconnectShare() } }

            let trimmedPath = server.path.trimmingCharacters(in: .whitespacesAndNewlines)
            let remotePath = trimmedPath.isEmpty ? filename : "\(trimmedPath)/\(filename)"
            try await client.write(data: data, toPath: remotePath, progress: nil)
        } catch {
            throw SMBError.connectionFailed(error)
        }
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

    // MARK: - Helpers

    /// Builds an `SMB2Manager` client for the given server configuration.
    private func makeClient(for server: SMBServer) throws -> SMB2Manager {
        guard !server.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: "smb://\(server.host)") else {
            throw SMBError.invalidHost
        }
        let credential = URLCredential(user: server.username, password: server.password, persistence: .forSession)
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBError.invalidHost
        }
        return client
    }
}
