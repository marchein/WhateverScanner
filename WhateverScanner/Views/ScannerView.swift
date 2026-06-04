import SwiftUI
import VisionKit

/// UIViewControllerRepresentable wrapper around `VNDocumentCameraViewController`.
/// Presents the system document scanner and delivers scan results via a completion handler.
struct ScannerView: UIViewControllerRepresentable {
    /// Closure called when scanning completes or fails.
    let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void

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
        Coordinator(onCompletion: onCompletion)
    }

    // MARK: - Coordinator

    /// Coordinator that bridges `VNDocumentCameraViewControllerDelegate` callbacks to the SwiftUI completion handler.
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        /// The completion handler to invoke with the scan result.
        let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void

        /// Initializes the coordinator with the given completion handler.
        /// - Parameter onCompletion: Closure called when scanning finishes or fails.
        init(onCompletion: @escaping (Result<VNDocumentCameraScan, Error>) -> Void) {
            self.onCompletion = onCompletion
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
            controller.dismiss(animated: true)
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
