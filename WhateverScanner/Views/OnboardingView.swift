import SwiftUI

/// Onboarding flow shown on first launch. Guides the user through a welcome screen
/// and initial WebDAV server setup before entering the main application.
struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var currentPage = 0
    @State private var serverName = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                serverSetupPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Pages

    /// The initial welcome page introducing the app and its purpose.
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("WhateverScanner")
                .font(.largeTitle.bold())

            Text("Scan documents and upload them directly to your WebDAV server — e.g. Nextcloud.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button("Get Started") {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 40)
        }
        .padding()
    }

    /// The server configuration page where the user enters WebDAV credentials.
    private var serverSetupPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "server.rack")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 20)

                Text("Set Up Your Server")
                    .font(.title.bold())

                Text("Enter your WebDAV server details. You can add or change servers later in Settings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    serverField(label: "Name", placeholder: "My Nextcloud", text: $serverName)
                        .textContentType(.name)
                    Divider().padding(.leading)
                    serverField(label: "Server URL",
                                placeholder: "https://cloud.example.com/remote.php/dav/files/user/",
                                text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Divider().padding(.leading)
                    serverField(label: "Username", placeholder: "Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Divider().padding(.leading)
                    LabeledContent("Password") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button("Save & Start Scanning") {
                    saveServer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid)
                .padding(.bottom, 40)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    /// Creates a labeled text field row for the server setup form.
    /// - Parameters:
    ///   - label: The label displayed alongside the text field.
    ///   - placeholder: Placeholder text shown when the field is empty.
    ///   - text: A binding to the text value entered by the user.
    /// - Returns: A view containing the labeled text field.
    @ViewBuilder
    private func serverField(label: String, placeholder: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }

    /// Whether all required server fields have been filled in by the user.
    private var isFormValid: Bool {
        !serverName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    /// Validates the form input and saves the new server to app settings, then completes setup.
    private func saveServer() {
        var urlString = serverURL.trimmingCharacters(in: .whitespaces)
        if !urlString.hasSuffix("/") { urlString += "/" }

        guard URL(string: urlString) != nil else {
            errorMessage = "Please enter a valid server URL."
            showError = true
            return
        }

        let server = WebDAVServer(
            name: serverName.trimmingCharacters(in: .whitespaces),
            url: urlString,
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        settings.addServer(server)
        settings.completeSetup()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings())
}
