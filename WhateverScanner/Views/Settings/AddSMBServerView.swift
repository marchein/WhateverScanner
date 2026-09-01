import SwiftUI

/// Form view for adding a new SMB server or editing an existing one.
/// Supports connection testing before saving.
struct AddSMBServerView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing server.
    var existingServer: SMBServer?

    @State private var name: String
    @State private var host: String
    @State private var share: String
    @State private var path: String
    @State private var username: String
    @State private var password: String

    @State private var isTesting = false
    @State private var testResult: TestResult?

    // MARK: - Init

    /// Initializes the view, optionally pre-populating fields from an existing server for editing.
    /// - Parameter server: An existing server to edit, or `nil` to create a new one.
    init(server: SMBServer? = nil) {
        self.existingServer = server
        _name     = State(initialValue: server?.name     ?? "")
        _host     = State(initialValue: server?.host     ?? "")
        _share    = State(initialValue: server?.share    ?? "")
        _path     = State(initialValue: server?.path     ?? "")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
    }

    /// Whether editing an existing server (true) or adding a new one (false).
    private var isEditing: Bool { existingServer != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("SMB Server Details") {
                    LabeledContent("Name") {
                        TextField("My NAS", text: $name)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: name) { resetTestResult() }
                    }

                    LabeledContent("Host") {
                        TextField("192.168.1.10", text: $host)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: host) { resetTestResult() }
                    }

                    LabeledContent("Share") {
                        TextField("Scans", text: $share)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: share) { resetTestResult() }
                    }

                    LabeledContent("Path") {
                        TextField("Optional/Sub/Folder", text: $path)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: path) { resetTestResult() }
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
                            connectionStatusIndicator
                        }
                    }
                    .disabled(!isFormValid || isTesting)
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit SMB Server") : String(localized: "Add SMB Server"))
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
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !share.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the Save button should be enabled.
    /// Requires a valid form and a successful connection test.
    private var isSaveEnabled: Bool {
        guard isFormValid else { return false }
        if case .success = testResult { return true }
        return false
    }

    // MARK: - Actions

    /// Resets the connection test result when any input field changes.
    private func resetTestResult() {
        testResult = nil
    }

    /// Normalizes a user-entered path by trimming slashes.
    private func normalizedPath() -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    /// Initiates an asynchronous connection test against the configured server.
    private func testConnection() {
        isTesting = true
        testResult = nil
        let server = SMBServer(
            name: name,
            host: host.trimmingCharacters(in: .whitespaces),
            share: share.trimmingCharacters(in: .whitespaces),
            path: normalizedPath(),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        Task {
            do {
                try await SMBService.shared.testConnection(to: server)
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
        let server = SMBServer(
            id: existingServer?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            share: share.trimmingCharacters(in: .whitespaces),
            path: normalizedPath(),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )

        if isEditing {
            settings.updateSMBServer(server)
        } else {
            settings.addSMBServer(server)
        }
        dismiss()
    }
}

// MARK: - TestResult

/// Represents the outcome of an SMB connection test.
private enum TestResult {
    /// The connection test succeeded.
    case success
    /// The connection test failed with the given error message.
    case failure(String)
}

#Preview {
    AddSMBServerView()
        .environmentObject(AppSettings())
}
