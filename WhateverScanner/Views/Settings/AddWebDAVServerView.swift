import SwiftUI

/// Form view for adding a new WebDAV server or editing an existing one.
/// Supports connection testing via PROPFIND before saving.
struct AddWebDAVServerView: View {
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
                Section("WebDAV Server Details") {
                    LabeledContent("Name") {
                        TextField("My Nextcloud", text: $name)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: name) { resetTestResult() }
                    }

                    // Keep URL in the same row layout as other fields so
                    // alignment is consistent across the whole form.
                    LabeledContent("URL") {
                        TextField("https://<server-url>/dav/", text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: url) { resetTestResult() }
                    }

                    LabeledContent("Username") {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: username) { resetTestResult() }
                    }

                    LabeledContent("Password") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: password) { resetTestResult() }
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text(isTesting ? String(localized: "Testing…") : String(localized: "Test Connection"))
                            Spacer()
                            // Show a spinner while testing, a green checkmark on success,
                            // or a red cross on failure.
                            connectionStatusIndicator
                        }
                    }
                    .disabled(!isFormValid || isTesting)
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit Server") : String(localized: "Add Server"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveServer() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isSaveEnabled)
                }
            }
        }
    }

    // MARK: - Status Indicator

    /// Displays the appropriate inline indicator based on the current connection test state.
    @ViewBuilder
    private var connectionStatusIndicator: some View {
        if isTesting {
            ProgressView()
        } else if let result = testResult {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
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

    /// Whether the Save button should be enabled.
    /// Requires a valid form and a successful connection test.
    private var isSaveEnabled: Bool {
        guard isFormValid else { return false }
        if case .success = testResult { return true }
        return false
    }

    // MARK: - Actions

    /// Returns the server URL with a trailing slash appended if needed.
    /// - Returns: The normalized URL string.
    private func normalizedURL() -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        if !s.hasSuffix("/") { s += "/" }
        return s
    }

    /// Resets the connection test result when any input field changes.
    private func resetTestResult() {
        testResult = nil
    }

    /// Initiates an asynchronous connection test against the configured server using PROPFIND.
    private func testConnection() {
        isTesting = true
        testResult = nil
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
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
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
    AddWebDAVServerView()
        .environmentObject(AppSettings())
}
