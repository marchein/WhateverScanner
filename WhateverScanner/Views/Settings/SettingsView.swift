import SwiftUI

/// Settings screen allowing users to configure scan behaviour, upload preferences,
/// and manage WebDAV server connections.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showAddServer = false
    @State private var serverToEdit: WebDAVServer?

    @State private var showAddSMBServer = false
    @State private var smbServerToEdit: SMBServer?
    @State private var showFolderPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Scan Behaviour
                Section("Scan Behaviour") {
                    Toggle("Auto-Start Scanner on Launch", isOn: $settings.autoStartScan)
                }

                // MARK: Auto-Save Destinations
                Section {
                    Toggle("Save to Photos", isOn: $settings.autoSaveToPhotos)

                    Toggle("Save PDF to Files", isOn: $settings.autoSaveToFiles)

                    Button {
                        showFolderPicker = true
                    } label: {
                        LabeledContent("Folder") {
                            Text(settings.filesFolderName ?? String(localized: "WhateverScanner (Default)"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Auto-Save")
                } footer: {
                    Text("Automatically save every scan as images to Photos and/or as a PDF to a folder in the Files app. If no folder is selected, PDFs are saved to the app's own WhateverScanner folder in Files.")
                }

                // MARK: WebDAV
                Section {
                    if settings.servers.count > 0 {
                        Toggle("Auto-Upload to WebDAV Server", isOn: $settings.autoUploadToWebDAV)
                    }

                    if settings.servers.count > 1 {
                        Toggle("Upload to All Servers", isOn: $settings.uploadToAllServers)

                        if !settings.uploadToAllServers {
                            Picker("Default Server", selection: Binding(
                                get: { settings.defaultServerId },
                                set: { settings.defaultServerId = $0 }
                            )) {
                                ForEach(settings.servers) { server in
                                    Text(server.name).tag(server.id as UUID?)
                                }
                            }
                        }
                    }

                    if settings.servers.count > 0 {
                        ForEach(settings.servers) { server in
                            serverRow(server)
                        }
                    }
                    
                    Button {
                        showAddServer = true
                    } label: {
                        Label("Add WebDAV Server", systemImage: "plus")
                    }
                } header: {
                    Text("WebDAV")
                }

                // MARK: SMB
                Section {
                    if settings.smbServers.count > 0 {
                        Toggle("Auto-Upload to SMB Server", isOn: $settings.autoUploadToSMB)
                    }

                    if settings.smbServers.count > 1 {
                        Toggle("Upload to All SMB Servers", isOn: $settings.uploadToAllSMBServers)

                        if !settings.uploadToAllSMBServers {
                            Picker("Default SMB Server", selection: Binding(
                                get: { settings.defaultSMBServerId },
                                set: { settings.defaultSMBServerId = $0 }
                            )) {
                                ForEach(settings.smbServers) { server in
                                    Text(server.name).tag(server.id as UUID?)
                                }
                            }
                        }
                    }

                    if settings.smbServers.count > 0 {
                        ForEach(settings.smbServers) { server in
                            smbServerRow(server)
                        }
                    }
                    
                    Button {
                        showAddSMBServer = true
                    } label: {
                        Label("Add SMB Server", systemImage: "plus")
                    }
                } header: {
                    Text("SMB")
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
                AddWebDAVServerView()
            }
            .sheet(item: $serverToEdit) { server in
                AddWebDAVServerView(server: server)
            }
            .sheet(isPresented: $showAddSMBServer) {
                AddSMBServerView()
            }
            .sheet(item: $smbServerToEdit) { server in
                AddSMBServerView(server: server)
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView { bookmark, name in
                    settings.filesFolderBookmark = bookmark
                    settings.filesFolderName = name
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Server Row

    /// Builds a row for a single server, showing its name, URL, and default status.
    ///
    /// Uses standard iOS swipe actions for editing and deleting:
    /// - **Swipe right** (leading edge): Reveals an "Edit" button.
    /// - **Swipe left** (trailing edge): Reveals a destructive "Delete" button.
    ///
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
                    .lineLimit(3)
            }

            Spacer()

            if server.id == settings.defaultServerId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            serverToEdit = server
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let index = settings.servers.firstIndex(where: { $0.id == server.id }) {
                    settings.removeServer(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - SMB Server Row

    /// Builds a row for a single SMB share, showing its name, host, and default status.
    /// - Parameter server: The SMB server to display.
    /// - Returns: A view representing the share row.
    @ViewBuilder
    private func smbServerRow(_ server: SMBServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)
                Text("\(server.host)/\(server.share)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()

            if server.id == settings.defaultSMBServerId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            smbServerToEdit = server
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let index = settings.smbServers.firstIndex(where: { $0.id == server.id }) {
                    settings.removeSMBServer(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
