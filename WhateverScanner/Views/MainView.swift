import SwiftUI
import VisionKit

struct MainView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var showScanner = false
    @State private var showSettings = false
    @State private var isUploading = false
    @State private var uploadStatus: UploadStatus?
    @State private var showUploadResult = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.accent)

                Text("Ready to Scan")
                    .font(.largeTitle.bold())

                uploadDestinationLabel

                Spacer()

                if isUploading {
                    ProgressView("Uploading…")
                        .controlSize(.large)
                } else {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Document", systemImage: "camera.viewfinder")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("WhateverScanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView { result in
                    showScanner = false
                    handleScanResult(result)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(uploadAlertTitle, isPresented: $showUploadResult) {
                Button("OK") {}
            } message: {
                Text(uploadAlertMessage)
            }
        }
        .onAppear {
            if settings.autoStartScan {
                showScanner = true
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var uploadDestinationLabel: some View {
        if settings.servers.isEmpty {
            EmptyView()
        } else if settings.uploadToAllServers {
            Text("Uploading to: All servers (\(settings.servers.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let server = settings.defaultServer {
            Text("Uploading to: \(server.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Alert Helpers

    private var uploadAlertTitle: String {
        guard let status = uploadStatus else { return "" }
        if case .success = status { return "Upload Successful" }
        return "Upload Failed"
    }

    private var uploadAlertMessage: String {
        switch uploadStatus {
        case .success(let count):
            return "Document uploaded to \(count) server\(count == 1 ? "" : "s")."
        case .failure(let message):
            return message
        case nil:
            return ""
        }
    }

    // MARK: - Scan Handling

    private func handleScanResult(_ result: Result<VNDocumentCameraScan, Error>) {
        switch result {
        case .success(let scan):
            guard scan.pageCount > 0 else { return }
            Task { await uploadScan(scan) }
        case .failure(let error):
            uploadStatus = .failure("Scan failed: \(error.localizedDescription)")
            showUploadResult = true
        }
    }

    @MainActor
    private func uploadScan(_ scan: VNDocumentCameraScan) async {
        isUploading = true

        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }

        guard let pdfData = PDFService.shared.createPDF(from: images) else {
            isUploading = false
            uploadStatus = .failure("Failed to create PDF from the scanned pages.")
            showUploadResult = true
            return
        }

        let filename = PDFService.shared.generateFilename()
        let targets = settings.uploadTargets
        var successCount = 0
        var errors: [String] = []

        for server in targets {
            do {
                try await WebDAVService.shared.upload(data: pdfData, filename: filename, to: server)
                successCount += 1
            } catch {
                errors.append("\(server.name): \(error.localizedDescription)")
            }
        }

        isUploading = false

        if errors.isEmpty {
            uploadStatus = .success(successCount)
        } else if successCount > 0 {
            uploadStatus = .failure(
                "Uploaded to \(successCount) server(s), but failed:\n\(errors.joined(separator: "\n"))"
            )
        } else {
            uploadStatus = .failure("Upload failed:\n\(errors.joined(separator: "\n"))")
        }
        showUploadResult = true
    }
}

// MARK: - UploadStatus

private enum UploadStatus {
    case success(Int)
    case failure(String)
}

#Preview {
    MainView()
        .environmentObject(AppSettings())
}
