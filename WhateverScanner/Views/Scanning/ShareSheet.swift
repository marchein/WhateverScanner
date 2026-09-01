import SwiftUI
import UIKit

/// A `UIViewControllerRepresentable` wrapper around `UIActivityViewController`,
/// used to present the iOS share sheet for exporting scanned documents.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
