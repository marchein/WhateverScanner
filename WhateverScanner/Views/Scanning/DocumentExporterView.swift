import SwiftUI
import UniformTypeIdentifiers

/// A `UIViewControllerRepresentable` wrapper around `UIDocumentPickerViewController`
/// configured for exporting a single file, letting the user choose any destination
/// in the Files app without requiring a persisted bookmark.
struct DocumentExporterView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
