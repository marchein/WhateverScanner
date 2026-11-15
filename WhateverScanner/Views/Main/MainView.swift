import SwiftUI
import VisionKit

/// The primary view of the app, displaying the scan button and upload status.
/// Handles document scanning via VisionKit and presenting a preview with OCR-based suggestions.
struct MainView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var showScanner = false
    @State private var showSettings = false
    @State private var showScanError = false
    @State private var scanErrorMessage = ""

    /// Set once the scanner was opened automatically, so "Auto-Start Scanner on Launch"
    /// only triggers once per launch (`onAppear` also fires again whenever a
    /// full-screen cover such as the preview is dismissed).
    @State private var hasAutoStarted = false

    /// Result delivered by the document camera, processed once the camera has
    /// been fully dismissed (presenting the preview while the camera is still
    /// animating out would be silently dropped by SwiftUI).
    @State private var pendingScanResult: Result<VNDocumentCameraScan, Error>?

    // Preview state
    @State private var preview: ScanPreviewData?
    @State private var isAnalyzing = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainView
                .navigationTitle("WhateverScanner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel(Text("Settings"))
                    }
                }
                .fullScreenCover(isPresented: $showScanner, onDismiss: processPendingScanResult) {
                    ScannerView(
                        onCompletion: { result in
                            pendingScanResult = result
                            showScanner = false
                        },
                        onCancel: {
                            showScanner = false
                        }
                    )
                    .ignoresSafeArea()
                }
                .fullScreenCover(item: $preview) { preview in
                    ScanPreviewView(
                        images: preview.images,
                        pdfData: preview.pdfData,
                        documentInfo: preview.documentInfo,
                        scanDate: preview.scanDate,
                        onDismiss: { self.preview = nil }
                    )
                    .environmentObject(settings)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environmentObject(settings)
                }
                .alert(String(localized: "Scan Error"), isPresented: $showScanError) {
                    Button("OK") {}
                } message: {
                    Text(scanErrorMessage)
                }
        }
        .onAppear {
            if settings.autoStartScan && !hasAutoStarted {
                hasAutoStarted = true
                startScan()
            }
        }
    }

    // MARK: - Sub-views
    
    /// Displays the primary main view shown when the app is started
    @ViewBuilder
    private var mainView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "document.viewfinder.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            
            Text("Ready to Scan")
                .font(.largeTitle.bold())
            
            uploadDestinationLabel
            
            Spacer()
            
            if isAnalyzing {
                ProgressView("Analyzing…")
                    .controlSize(.large)
            } else {
                Button {
                    startScan()
                } label: {
                    Label("Scan Document", systemImage: "camera.viewfinder")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    /// Displays all currently enabled save/upload destinations based on user settings.
    /// Tapping the label opens Settings so the user can adjust destinations.
    @ViewBuilder
    private var uploadDestinationLabel: some View {
        Button {
            showSettings = true
        } label: {
            VStack(spacing: 4) {
                if destinationDescriptions.isEmpty {
                    Text("No destinations configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(destinationDescriptions, id: \.self) { description in
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
    }

    /// The list of human-readable descriptions for every enabled save/upload destination.
    /// Save destinations (Photos/Files) and upload destinations (WebDAV/SMB) are each
    /// combined into a single line so the prefix ("Saving to:"/"Uploading to:") only
    /// appears once per group.
    private var destinationDescriptions: [String] {
        var saveTargets: [String] = []
        var uploadTargets: [String] = []

        if settings.autoSaveToPhotos {
            saveTargets.append(String(localized: "Photos"))
        }

        if settings.autoSaveToFiles {
            saveTargets.append(settings.filesFolderName ?? String(localized: "Files"))
        }

        if settings.autoUploadToWebDAV && !settings.servers.isEmpty {
            if settings.uploadToAllServers {
                uploadTargets.append(String(localized: "All servers (\(settings.servers.count))"))
            } else if let server = settings.defaultServer {
                uploadTargets.append(server.name)
            }
        }

        if settings.autoUploadToSMB && !settings.smbServers.isEmpty {
            if settings.uploadToAllSMBServers {
                uploadTargets.append(String(localized: "All SMB shares (\(settings.smbServers.count))"))
            } else if let server = settings.defaultSMBServer {
                uploadTargets.append(server.name)
            }
        }

        var descriptions: [String] = []
        if !saveTargets.isEmpty {
            descriptions.append(String(localized: "Saving to: \(saveTargets.joined(separator: ", "))"))
        }
        if !uploadTargets.isEmpty {
            descriptions.append(String(localized: "Uploading to: \(uploadTargets.joined(separator: ", "))"))
        }

        return descriptions
    }

    // MARK: - Scan Handling

    /// Opens the document camera, or explains why it isn't available.
    private func startScan() {
        guard ScannerView.isSupported else {
            scanErrorMessage = String(localized: "Document scanning isn't supported on this device.")
            showScanError = true
            return
        }
        showScanner = true
    }

    /// Called once the document camera has been fully dismissed. Processes the
    /// scan result (if any) that the camera delivered.
    private func processPendingScanResult() {
        guard let result = pendingScanResult else { return }
        pendingScanResult = nil

        switch result {
        case .success(let scan):
            guard scan.pageCount > 0 else { return }
            Task { await prepareScanPreview(scan) }
        case .failure(let error):
            Log.scan.error("Document camera failed: \(error.localizedDescription, privacy: .private)")
            scanErrorMessage = String(localized: "Scan failed: \(error.localizedDescription)")
            showScanError = true
        }
    }

    /// Converts the scanned pages to a PDF, runs OCR analysis, and presents the preview.
    /// The heavy lifting (PDF rendering and text recognition) runs off the main thread.
    /// - Parameter scan: The document camera scan containing one or more pages.
    @MainActor
    private func prepareScanPreview(_ scan: VNDocumentCameraScan) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let scanDate = Date()
        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }

        async let pdfTask = Task.detached(priority: .userInitiated) {
            PDFService.shared.createPDF(from: images)
        }.value
        async let infoTask = OCRService.shared.analyzeDocument(images: images)
        let (pdfData, documentInfo) = await (pdfTask, infoTask)

        guard let pdfData else {
            Log.scan.error("PDF creation failed for \(images.count) page(s)")
            scanErrorMessage = String(localized: "Failed to create PDF from the scanned pages.")
            showScanError = true
            return
        }

        preview = ScanPreviewData(
            images: images,
            pdfData: pdfData,
            documentInfo: documentInfo,
            scanDate: scanDate
        )
    }
}

// MARK: - Supporting Types

/// Everything the scan preview needs, bundled so it can drive
/// `fullScreenCover(item:)` and be released as a whole once the preview closes.
private struct ScanPreviewData: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let pdfData: Data
    let documentInfo: OCRService.DocumentInfo
    let scanDate: Date
}

#Preview {
    MainView()
        .environmentObject(AppSettings())
}
