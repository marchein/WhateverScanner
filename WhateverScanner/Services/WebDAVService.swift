import Foundation

// MARK: - Errors

enum WebDAVError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case serverError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .authenticationFailed:
            return "Authentication failed. Check your username and password."
        case .serverError(let code):
            return "Server returned error code \(code)."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Service

actor WebDAVService {
    static let shared = WebDAVService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    /// Upload PDF data to a WebDAV server using HTTP PUT.
    func upload(data: Data, filename: String, to server: WebDAVServer) async throws {
        let urlString = server.url + filename
        guard let url = URL(string: urlString) else {
            throw WebDAVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue(basicAuthHeader(username: server.username, password: server.password),
                         forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.upload(for: request, from: data)
        try validate(response: response)
    }

    /// Test connectivity and authentication via WebDAV PROPFIND.
    func testConnection(to server: WebDAVServer) async throws {
        guard let url = URL(string: server.url) else {
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
            throw WebDAVError.networkError(error)
        }
    }

    // MARK: - Helpers

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

    private func basicAuthHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else { return "" }
        return "Basic \(data.base64EncodedString())"
    }
}
