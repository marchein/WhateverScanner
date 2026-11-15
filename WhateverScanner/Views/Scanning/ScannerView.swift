import SwiftUI
import VisionKit

/// UIViewControllerRepresentable wrapper around `VNDocumentCameraViewController`.
/// Presents the system document scanner and delivers scan results via a completion handler.
struct ScannerView: UIViewControllerRepresentable {
    /// Whether the current device supports the document camera
    /// (e.g. `false` in the Simulator or on devices without a suitable camera).
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    /// Closure called when scanning completes or fails.
    let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void
    /// Closure called when the user cancels scanning. The presenting view is
    /// responsible for dismissing the scanner (so SwiftUI's presentation state
    /// stays in sync with what is actually on screen).
    let onCancel: () -> Void

    /// Creates and returns the `VNDocumentCameraViewController` with its delegate configured.
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    /// Called when SwiftUI updates the view controller. No-op for the document camera.
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    /// Creates the coordinator that acts as the document camera delegate.
    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancel: onCancel)
    }

    // MARK: - Coordinator

    /// Coordinator that bridges `VNDocumentCameraViewControllerDelegate` callbacks to the SwiftUI completion handler.
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        /// The completion handler to invoke with the scan result.
        let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void
        /// The handler to invoke when the user cancels.
        let onCancel: () -> Void

        /// Initializes the coordinator with the given handlers.
        /// - Parameters:
        ///   - onCompletion: Closure called when scanning finishes or fails.
        ///   - onCancel: Closure called when the user cancels.
        init(
            onCompletion: @escaping (Result<VNDocumentCameraScan, Error>) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCompletion = onCompletion
            self.onCancel = onCancel
        }

        /// Called when the user successfully scans one or more pages.
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            onCompletion(.success(scan))
        }

        /// Called when the user cancels the scanning session.
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            // Don't call `controller.dismiss` here: the camera is hosted in a SwiftUI
            // `fullScreenCover`, and dismissing it behind SwiftUI's back leaves the
            // `isPresented` binding stuck at `true`, so the scanner can't be opened again.
            onCancel()
        }

        /// Called when scanning fails due to an error.
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCompletion(.failure(error))
        }
    }
}
