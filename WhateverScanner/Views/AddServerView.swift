import SwiftUI

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

    init(server: WebDAVServer? = nil) {
        self.existingServer = server
        _name     = State(initialValue: server?.name     ?? "")
        _url      = State(initialValue: server?.url      ?? "")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
    }

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
                            Text(isTesting ? "Testing…" : "Test Connection")
                        }
                    }
                    .disabled(!isFormValid || isTesting)
                }
            }
            .navigationTitle(isEditing ? "Edit Server" : "Add Server")
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

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Alert Helpers

    private var testResultTitle: String {
        if case .success = testResult { return "Connection Successful" }
        return "Connection Failed"
    }

    private var testResultMessage: String {
        switch testResult {
        case .success:        return "Successfully connected to the server."
        case .failure(let m): return m
        case nil:             return ""
        }
    }

    // MARK: - Actions

    private func normalizedURL() -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        if !s.hasSuffix("/") { s += "/" }
        return s
    }

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

private enum TestResult {
    case success
    case failure(String)
}

#Preview {
    AddServerView()
        .environmentObject(AppSettings())
}
