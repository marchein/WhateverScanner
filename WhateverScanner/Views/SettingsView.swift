import SwiftUI

/// Settings screen allowing users to configure scan behaviour, upload preferences,
/// and manage WebDAV server connections.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showAddServer = false
    @State private var serverToEdit: WebDAVServer?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Scan Behaviour
                Section("Scan Behaviour") {
                    Toggle("Auto-Start Scanner on Launch", isOn: $settings.autoStartScan)
                }

                // MARK: Upload
                Section {
                    Toggle("Upload to All Servers", isOn: $settings.uploadToAllServers)

                    if !settings.uploadToAllServers, settings.servers.count > 1 {
                        Picker("Default Server", selection: Binding(
                            get: { settings.defaultServerId },
                            set: { settings.defaultServerId = $0 }
                        )) {
                            ForEach(settings.servers) { server in
                                Text(server.name).tag(server.id as UUID?)
                            }
                        }
                    }
                } header: {
                    Text("Upload")
                } footer: {
                    if !settings.uploadToAllServers {
                        Text("When disabled, scans are uploaded to the selected default server only.")
                    }
                }

                // MARK: Servers
                Section {
                    ForEach(settings.servers) { server in
                        serverRow(server)
                    }
                    .onDelete { settings.removeServer(at: $0) }

                    Button {
                        showAddServer = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    if !settings.uploadToAllServers, settings.servers.count > 1 {
                        Text("Tap a server row to make it the default upload destination.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddServer) {
                AddServerView()
            }
            .sheet(item: $serverToEdit) { server in
                AddServerView(server: server)
            }
        }
    }

    // MARK: - Server Row

    /// Builds a row for a single server, showing its name, URL, default status, and an edit button.
    /// - Parameter server: The WebDAV server to display.
    /// - Returns: A view representing the server row.
    @ViewBuilder
    private func serverRow(_ server: WebDAVServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)
                Text(server.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if server.id == settings.defaultServerId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button {
                serverToEdit = server
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !settings.uploadToAllServers {
                settings.setDefaultServer(server)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
