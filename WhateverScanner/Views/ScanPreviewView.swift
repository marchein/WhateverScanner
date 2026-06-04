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
                    Button(String(localized: "Cancel")) {
                        onDismiss()
                    }
                    .disabled(isUploading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Button(String(localized: "Upload")) {
                            Task { await upload() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(isPresented: $isEditingName) {
                editSheet
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

    /// Uploads the PDF to configured servers.
    @MainActor
    private func upload() async {
        isUploading = true

        let filename = generateFilename()
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
            let errorSummary = errors.joined(separator: "\n")
            uploadStatus = .failure(
                String(localized: "Uploaded to \(successCount) server(s), but failed:") + "\n" + errorSummary
            )
        } else {
            let errorSummary = errors.joined(separator: "\n")
            uploadStatus = .failure(String(localized: "Upload failed:") + "\n" + errorSummary)
        }
        showUploadResult = true
    }

    // MARK: - Alert Helpers

    private var uploadAlertTitle: String {
        guard let status = uploadStatus else { return "" }
        if case .success = status { return String(localized: "Upload Successful") }
        return String(localized: "Upload Failed")
    }

    private var uploadAlertMessage: String {
        switch uploadStatus {
        case .success(let count):
            return String(localized: "Document uploaded to \(count) server(s).")
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
