import SwiftUI
import VisionKit

/// UIViewControllerRepresentable wrapper around VNDocumentCameraViewController.
struct ScannerView: UIViewControllerRepresentable {
    let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCompletion: (Result<VNDocumentCameraScan, Error>) -> Void

        init(onCompletion: @escaping (Result<VNDocumentCameraScan, Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            onCompletion(.success(scan))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCompletion(.failure(error))
        }
    }
}
