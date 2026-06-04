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
                Spacer()

                Image(systemName: "doc.text.viewfinder")
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

    /// Displays the current upload destination based on user settings.
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
