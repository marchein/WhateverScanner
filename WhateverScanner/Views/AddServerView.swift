import SwiftUI

/// Form view for adding a new WebDAV server or editing an existing one.
/// Supports connection testing via PROPFIND before saving.
struct AddServerView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing server.
    var existingServer: WebDAVServer?

    @State private var name: String
    @State private var url: String
    @State private var username: String
    @State private var password: String

    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showTestResult = false

    // MARK: - Init

    /// Initializes the view, optionally pre-populating fields from an existing server for editing.
    /// - Parameter server: An existing server to edit, or `nil` to create a new one.
    init(server: WebDAVServer? = nil) {
        self.existingServer = server
        _name     = State(initialValue: server?.name     ?? "")
        _url      = State(initialValue: server?.url      ?? "")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
    }

    /// Whether editing an existing server (true) or adding a new one (false).
    private var isEditing: Bool { existingServer != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    LabeledContent("Name") {
                        TextField("My Nextcloud", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("URL") {
                        TextField(
                            "https://cloud.example.com/remote.php/dav/files/user/",
                            text: $url
                        )
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Username") {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Password") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text(isTesting ? String(localized: "Testing…") : String(localized: "Test Connection"))
                        }
                    }
                    .disabled(!isFormValid || isTesting)
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit Server") : String(localized: "Add Server"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveServer() }
                        .disabled(!isFormValid)
                }
            }
            .alert(testResultTitle, isPresented: $showTestResult) {
                Button("OK") {}
            } message: {
                Text(testResultMessage)
            }
        }
    }

    // MARK: - Validation

    /// Whether all required server fields have been filled in.
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Alert Helpers

    /// The title string for the connection test result alert.
    private var testResultTitle: String {
        if case .success = testResult { return String(localized: "Connection Successful") }
        return String(localized: "Connection Failed")
    }

    /// The message body for the connection test result alert.
    private var testResultMessage: String {
        switch testResult {
        case .success:        return String(localized: "Successfully connected to the server.")
        case .failure(let m): return m
        case nil:             return ""
        }
    }

    // MARK: - Actions

    /// Returns the server URL with a trailing slash appended if needed.
    /// - Returns: The normalized URL string.
    private func normalizedURL() -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        if !s.hasSuffix("/") { s += "/" }
        return s
    }

    /// Initiates an asynchronous connection test against the configured server using PROPFIND.
    private func testConnection() {
        isTesting = true
        let server = WebDAVServer(
            name: name,
            url: normalizedURL(),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        Task {
            do {
                try await WebDAVService.shared.testConnection(to: server)
                await MainActor.run {
                    isTesting = false
                    testResult = .success
                    showTestResult = true
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                    showTestResult = true
                }
            }
        }
    }

    /// Validates and saves the server configuration, then dismisses the view.
    private func saveServer() {
        let urlString = normalizedURL()
        guard URL(string: urlString) != nil else { return }

        let server = WebDAVServer(
            id: existingServer?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            url: urlString,
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )

        if isEditing {
            settings.updateServer(server)
        } else {
            settings.addServer(server)
        }
        dismiss()
    }
}

// MARK: - TestResult

/// Represents the outcome of a WebDAV connection test.
private enum TestResult {
    /// The connection test succeeded.
    case success
    /// The connection test failed with the given error message.
    case failure(String)
}

#Preview {
    AddServerView()
        .environmentObject(AppSettings())
}
