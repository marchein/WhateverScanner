import SwiftUI
import UniformTypeIdentifiers

/// A `UIViewControllerRepresentable` wrapper around `UIDocumentPickerViewController`
/// configured for picking a folder. Returns a security-scoped bookmark for the
/// selected folder so it can be accessed again in future launches.
struct FolderPickerView: UIViewControllerRepresentable {
    /// Called with the selected folder's bookmark data and display name, or `nil` if cancelled.
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String) -> Void

        init(onPick: @escaping (Data, String) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
                return
            }
            onPick(bookmark, url.lastPathComponent)
        }
    }
}
