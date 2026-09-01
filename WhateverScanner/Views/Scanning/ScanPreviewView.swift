import SwiftUI
import PDFKit

/// A preview view shown after scanning, displaying the PDF and allowing the user
/// to edit the document name and choose a date before uploading.
struct ScanPreviewView: View {
    @EnvironmentObject var settings: AppSettings

    /// The scanned page images.
    let images: [UIImage]
    /// The PDF data created from the scanned images.
    let pdfData: Data
    /// OCR analysis result with suggested name and date.
    let documentInfo: OCRService.DocumentInfo
    /// Called when the user confirms upload or cancels.
    let onDismiss: () -> Void

    @State private var documentName: String = ""
    @State private var selectedDateOption: DateOption = .scanDate
    @State private var isEditingName = false
    @State private var isUploading = false
    @State private var uploadStatus: UploadResult?
    @State private var showUploadResult = false

    // Manual export state (Share Sheet / Save to Photos / Save to Files),
    // available regardless of the destinations configured in Settings.
    @State private var isPerformingManualAction = false
    @State private var manualActionMessage: ManualActionMessage?
    @State private var showManualActionAlert = false
    @State private var shareItems: [URL] = []
    @State private var showShareSheet = false
    @State private var showDocumentExporter = false
    @State private var exportURL: URL?

    /// Whether OCR found a document date.
    private var hasDocumentDate: Bool {
        documentInfo.documentDate != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Document info bar – full-width, clearly tappable
                documentInfoBar

                Divider()

                // PDF Preview
                PDFPreviewRepresentable(data: pdfData)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(String(localized: "Scan Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Label(String(localized: "Cancel"), systemImage: "xmark")
                    }
                    .disabled(isUploading)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isUploading {
                        ProgressView()
                    } else {
                        if isPerformingManualAction {
                            ProgressView()
                        } else {
                            Menu {
                                Button {
                                    shareDocument()
                                } label: {
                                    Label(String(localized: "Share…"), systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    saveToPhotosManually()
                                } label: {
                                    Label(String(localized: "Save to Photos"), systemImage: "photo")
                                }
                                Button {
                                    exportToFilesManually()
                                } label: {
                                    Label(String(localized: "Save to Files"), systemImage: "folder")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        Button(String(localized: "Save")) {
                            Task { await upload() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(isPresented: $isEditingName) {
                editSheet
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .sheet(isPresented: $showDocumentExporter) {
                if let exportURL {
                    DocumentExporterView(url: exportURL)
                }
            }
            .alert(uploadAlertTitle, isPresented: $showUploadResult) {
                Button("OK") {
                    if case .success = uploadStatus {
                        onDismiss()
                    }
                }
            } message: {
                Text(uploadAlertMessage)
            }
            .alert(manualActionMessage?.title ?? "", isPresented: $showManualActionAlert) {
                Button("OK") {}
            } message: {
                Text(manualActionMessage?.message ?? "")
            }
        }
        .interactiveDismissDisabled(isUploading)
        .onAppear {
            documentName = documentInfo.suggestedName ?? "Scan"
            if hasDocumentDate {
                selectedDateOption = .documentDate
            }
        }
    }

    // MARK: - Document Info Bar

    /// A full-width tappable bar showing the document name and date with a clear edit affordance.
    private var documentInfoBar: some View {
        Button {
            isEditingName = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(documentName)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.bar)
    }

    // MARK: - Edit Sheet

    /// Sheet for editing the document name and date option.
    private var editSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Document Name")) {
                    TextField(String(localized: "Document Name"), text: $documentName)
                        .autocorrectionDisabled()
                }

                Section(String(localized: "Date")) {
                    Picker(String(localized: "Date"), selection: $selectedDateOption) {
                        Text(scanDateLabel).tag(DateOption.scanDate)
                        if hasDocumentDate {
                            Text(documentDateLabel).tag(DateOption.documentDate)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(String(localized: "Edit Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        isEditingName = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Date Formatting

    /// Cached formatters for date display to avoid repeated creation.
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let mediumDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// The currently selected date based on the user's choice.
    private var selectedDate: Date {
        switch selectedDateOption {
        case .scanDate:
            return Date()
        case .documentDate:
            return documentInfo.documentDate ?? Date()
        }
    }

    /// Formatted string for the currently selected date.
    private var formattedDate: String {
        Self.mediumDateTimeFormatter.string(from: selectedDate)
    }

    /// Label for the scan date option showing today's date.
    private var scanDateLabel: String {
        let dateStr = Self.mediumDateFormatter.string(from: Date())
        return String(localized: "Scan Date") + " (\(dateStr))"
    }

    /// Label for the document date option showing the OCR-detected date.
    private var documentDateLabel: String {
        guard let docDate = documentInfo.documentDate else { return "" }
        let dateStr = Self.mediumDateFormatter.string(from: docDate)
        return String(localized: "Document Date") + " (\(dateStr))"
    }

    // MARK: - Filename

    /// Generates the final filename from user's choices.
    private func generateFilename() -> String {
        let name = documentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = name.isEmpty ? "Scan" : sanitizeFilename(name)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateStr = formatter.string(from: selectedDate)

        return "\(safeName)_\(dateStr).pdf"
    }

    /// Removes characters that are unsafe for filenames.
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - Upload

    /// Saves and uploads the PDF to every destination enabled in Settings
    /// (WebDAV servers, Photos, a Files app folder, and/or SMB shares).
    @MainActor
    private func upload() async {
        guard settings.autoUploadToWebDAV || settings.autoSaveToPhotos || settings.autoSaveToFiles || settings.autoUploadToSMB else {
            uploadStatus = .failure(String(localized: "No destination is enabled in Settings. Enable one, or use the more menu to share, save to Photos, or save to Files."))
            showUploadResult = true
            return
        }

        isUploading = true

        let filename = generateFilename()
        var successCount = 0
        var errors: [String] = []

        if settings.autoUploadToWebDAV {
            for server in settings.uploadTargets {
                do {
                    try await WebDAVService.shared.upload(data: pdfData, filename: filename, to: server)
                    successCount += 1
                } catch {
                    errors.append("\(server.name): \(error.localizedDescription)")
                }
            }
        }

        if settings.autoSaveToPhotos {
            do {
                try await PhotosService.save(images: images)
                successCount += 1
            } catch {
                errors.append("\(String(localized: "Photos")): \(error.localizedDescription)")
            }
        }

        if settings.autoSaveToFiles {
            do {
                try FilesService.save(data: pdfData, filename: filename, bookmark: settings.filesFolderBookmark)
                successCount += 1
            } catch {
                errors.append("\(String(localized: "Files")): \(error.localizedDescription)")
            }
        }

        if settings.autoUploadToSMB {
            for server in settings.smbUploadTargets {
                do {
                    try await SMBService.shared.upload(data: pdfData, filename: filename, to: server)
                    successCount += 1
                } catch {
                    errors.append("\(server.name): \(error.localizedDescription)")
                }
            }
        }

        isUploading = false

        if errors.isEmpty {
            uploadStatus = .success(successCount)
        } else if successCount > 0 {
            let errorSummary = errors.joined(separator: "\n")
            uploadStatus = .failure(
                String(localized: "Saved to \(successCount) destination(s), but failed:") + "\n" + errorSummary
            )
        } else {
            let errorSummary = errors.joined(separator: "\n")
            uploadStatus = .failure(String(localized: "Save failed:") + "\n" + errorSummary)
        }
        showUploadResult = true
    }

    // MARK: - Manual Export Actions

    /// Writes the PDF to a temporary file so it can be shared or exported.
    /// - Returns: The temporary file's URL, or `nil` if writing failed.
    private func writeTempPDF() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(generateFilename())
        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Presents the iOS share sheet with the scanned PDF, regardless of configured destinations.
    private func shareDocument() {
        guard let url = writeTempPDF() else { return }
        shareItems = [url]
        showShareSheet = true
    }

    /// Saves the scanned pages as images to Photos, regardless of the Auto-Save setting.
    private func saveToPhotosManually() {
        isPerformingManualAction = true
        Task {
            do {
                try await PhotosService.save(images: images)
                await MainActor.run {
                    isPerformingManualAction = false
                    manualActionMessage = ManualActionMessage(
                        title: String(localized: "Saved"),
                        message: String(localized: "The scan was saved to Photos.")
                    )
                    showManualActionAlert = true
                }
            } catch {
                await MainActor.run {
                    isPerformingManualAction = false
                    manualActionMessage = ManualActionMessage(
                        title: String(localized: "Save Failed"),
                        message: error.localizedDescription
                    )
                    showManualActionAlert = true
                }
            }
        }
    }

    /// Presents a document exporter allowing the user to save the PDF to any Files location,
    /// regardless of the Auto-Save setting.
    private func exportToFilesManually() {
        guard let url = writeTempPDF() else { return }
        exportURL = url
        showDocumentExporter = true
    }

    // MARK: - Alert Helpers

    private var uploadAlertTitle: String {
        guard let status = uploadStatus else { return "" }
        if case .success = status { return String(localized: "Save Successful") }
        return String(localized: "Save Failed")
    }

    private var uploadAlertMessage: String {
        switch uploadStatus {
        case .success(let count):
            return String(localized: "Document saved to \(count) destination(s).")
        case .failure(let message):
            return message
        case nil:
            return ""
        }
    }
}

// MARK: - Supporting Types

/// Which date to use for the filename.
private enum DateOption {
    case scanDate
    case documentDate
}

/// Result of an upload operation.
private enum UploadResult {
    case success(Int)
    case failure(String)
}

/// A simple title/message pair shown after a manual export action completes.
private struct ManualActionMessage {
    let title: String
    let message: String
}

// MARK: - PDF Preview

/// A UIViewRepresentable that displays a PDF using PDFKit.
private struct PDFPreviewRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
