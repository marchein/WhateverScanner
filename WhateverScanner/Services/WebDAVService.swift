import Foundation

// MARK: - Errors

/// Errors that can occur during WebDAV operations.
enum WebDAVError: LocalizedError {
    /// The server URL could not be parsed.
    case invalidURL
    /// The server rejected the provided credentials.
    case authenticationFailed
    /// The server responded with an unexpected HTTP status code.
    case serverError(Int)
    /// A network-level error occurred.
    case networkError(Error)
    /// The connection was refused because it isn't encrypted (plain `http://` to a
    /// non-local host is blocked by App Transport Security).
    case insecureConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The server URL is invalid.")
        case .authenticationFailed:
            return String(localized: "Authentication failed. Check your username and password.")
        case .serverError(let code):
            return String(localized: "Server returned error code \(code).")
        case .networkError(let error):
            return error.localizedDescription
        case .insecureConnection:
            return String(localized: "Unencrypted http:// connections are only allowed to servers on your local network. Please use an https:// URL.")
        }
    }
}

// MARK: - Service

/// Thread-safe actor responsible for communicating with WebDAV servers.
/// Handles file uploads via HTTP PUT and connection testing via PROPFIND.
actor WebDAVService {
    /// Shared singleton instance.
    static let shared = WebDAVService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    /// Uploads PDF data to a WebDAV server using HTTP PUT.
    /// - Parameters:
    ///   - data: The PDF file data to upload.
    ///   - filename: The destination filename on the server.
    ///   - server: The target WebDAV server configuration.
    /// - Throws: `WebDAVError` if the URL is invalid or the server returns an error.
    func upload(data: Data, filename: String, to server: WebDAVServer) async throws {
        let url = try Self.uploadURL(for: server, filename: filename)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue(basicAuthHeader(username: server.username, password: server.password),
                         forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.upload(for: request, from: data)
            try validate(response: response)
        } catch let error as WebDAVError {
            throw error
        } catch {
            throw Self.mapNetworkError(error)
        }
    }

    /// Builds the destination URL for an uploaded file.
    ///
    /// The filename is appended as a properly percent-encoded path component, so
    /// names containing spaces, umlauts, `#`, `?` or `%` don't produce an invalid URL
    /// or end up in the query/fragment instead of the path.
    /// - Parameters:
    ///   - server: The target WebDAV server configuration.
    ///   - filename: The destination filename.
    /// - Returns: The full upload URL.
    /// - Throws: `WebDAVError.invalidURL` if the server URL can't be parsed.
    static func uploadURL(for server: WebDAVServer, filename: String) throws -> URL {
        guard let baseURL = validatedBaseURL(server.url) else {
            throw WebDAVError.invalidURL
        }
        return baseURL.appending(path: filename, directoryHint: .notDirectory)
    }

    /// Tests connectivity and authentication against a WebDAV server using a PROPFIND request.
    /// - Parameter server: The server configuration to test.
    /// - Throws: `WebDAVError` if the URL is invalid, authentication fails, or a network error occurs.
    func testConnection(to server: WebDAVServer) async throws {
        guard let url = Self.validatedBaseURL(server.url) else {
            throw WebDAVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue(basicAuthHeader(username: server.username, password: server.password),
                         forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.data(for: request)
            try validate(response: response)
        } catch let error as WebDAVError {
            throw error
        } catch {
            throw Self.mapNetworkError(error)
        }
    }

    // MARK: - Helpers

    /// Parses a server URL string, requiring an `http`/`https` scheme and a host.
    /// - Parameter string: The configured server URL.
    /// - Returns: The parsed URL, or `nil` if it isn't a usable WebDAV endpoint.
    static func validatedBaseURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }

    /// Maps low-level `URLError`s to a `WebDAVError`, giving App Transport Security
    /// failures a helpful message instead of the generic system one.
    private static func mapNetworkError(_ error: Error) -> WebDAVError {
        if let urlError = error as? URLError,
           urlError.code == .appTransportSecurityRequiresSecureConnection {
            return .insecureConnection
        }
        return .networkError(error)
    }

    /// Validates an HTTP response, throwing appropriate errors for non-success status codes.
    /// - Parameter response: The URL response to validate.
    /// - Throws: `WebDAVError.authenticationFailed` for 401, `WebDAVError.serverError` for other failures.
    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.serverError(0)
        }
        switch http.statusCode {
        case 200...299, 207:
            return
        case 401:
            throw WebDAVError.authenticationFailed
        default:
            throw WebDAVError.serverError(http.statusCode)
        }
    }

    /// Creates a Basic Authentication header value from the given credentials.
    /// - Parameters:
    ///   - username: The authentication username.
    ///   - password: The authentication password.
    /// - Returns: A `Basic` authorization header string.
    private func basicAuthHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else { return "" }
        return "Basic \(data.base64EncodedString())"
    }
}
