import SwiftUI
import VisionKit

/// The primary view of the app, displaying the scan button and upload status.
/// Handles document scanning via VisionKit and presenting a preview with OCR-based suggestions.
struct MainView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var showScanner = false
    @State private var showSettings = false
    @State private var showAddServer = false
    @State private var showScanError = false
    @State private var scanErrorMessage = ""

    // Preview state
    @State private var showPreview = false
    @State private var previewImages: [UIImage] = []
    @State private var previewPDFData: Data?
    @State private var previewDocumentInfo: OCRService.DocumentInfo?
    @State private var isAnalyzing = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if settings.servers.isEmpty && false {
                    noServerConfiguredView
                } else {
                    mainView
                }
            }
            .navigationTitle("WhateverScanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
            .fullScreenCover(isPresented: $showPreview) {
                if let pdfData = previewPDFData, let docInfo = previewDocumentInfo {
                    ScanPreviewView(
                        images: previewImages,
                        pdfData: pdfData,
                        documentInfo: docInfo,
                        onDismiss: { showPreview = false }
                    )
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAddServer) {
                AddWebDAVServerView()
            }
            .alert(String(localized: "Scan Error"), isPresented: $showScanError) {
                Button("OK") {}
            } message: {
                Text(scanErrorMessage)
            }
        }
        .onAppear {
            if settings.autoStartScan {
                showScanner = true
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
            
            Text("Ready to Scan")
                .font(.largeTitle.bold())
            
            uploadDestinationLabel
            
            Spacer()
            
            if isAnalyzing {
                ProgressView("Analyzing…")
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
            }
        }
        .padding()
    }

    /// Displays an empty state when no server has been configured yet.
    /// Provides a visual hint and a button that opens `AddWebDAVServerView` directly
    /// so the user can set up their first server without navigating through settings.
    @ViewBuilder
    private var noServerConfiguredView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text("No Server Configured")
                    .font(.largeTitle.bold())
            }
            
            Text("Add a server to start scanning and uploading documents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            
            Button {
                showAddServer = true
            } label: {
                Label("Add Server", systemImage: "plus")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
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

    /// Processes the result from the document camera, creating a PDF and running OCR analysis
    /// before showing the preview.
    /// - Parameter result: The scan result containing either a `VNDocumentCameraScan` or an error.
    private func handleScanResult(_ result: Result<VNDocumentCameraScan, Error>) {
        switch result {
        case .success(let scan):
            guard scan.pageCount > 0 else { return }
            Task { await prepareScanPreview(scan) }
        case .failure(let error):
            scanErrorMessage = String(localized: "Scan failed: \(error.localizedDescription)")
            showScanError = true
        }
    }

    /// Converts the scanned pages to a PDF, runs OCR analysis, and presents the preview.
    /// - Parameter scan: The document camera scan containing one or more pages.
    @MainActor
    private func prepareScanPreview(_ scan: VNDocumentCameraScan) async {
        isAnalyzing = true

        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }

        guard let pdfData = PDFService.shared.createPDF(from: images) else {
            isAnalyzing = false
            scanErrorMessage = String(localized: "Failed to create PDF from the scanned pages.")
            showScanError = true
            return
        }

        let documentInfo = await OCRService.shared.analyzeDocument(images: images)

        previewImages = images
        previewPDFData = pdfData
        previewDocumentInfo = documentInfo
        isAnalyzing = false
        showPreview = true
    }
}

#Preview {
    MainView()
        .environmentObject(AppSettings())
}
