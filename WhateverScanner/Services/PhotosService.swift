import Photos
import UIKit

// MARK: - Errors

/// Errors that can occur while saving images to the photo library.
enum PhotosServiceError: LocalizedError {
    /// The user denied or restricted photo library access.
    case accessDenied
    /// The Photos framework reported an error while saving.
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return String(localized: "Photo library access was denied. Enable it in Settings to save scans as images.")
        case .saveFailed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Service

/// Service responsible for saving scanned page images to the user's photo library.
enum PhotosService {

    /// Requests add-only photo library authorization if not already determined.
    /// - Returns: `true` if the app is authorized (fully or limited) to add photos.
    static func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    /// Saves the given images to the photo library as individual photos.
    /// - Parameter images: The scanned page images to save.
    /// - Throws: `PhotosServiceError` if access is denied or saving fails.
    static func save(images: [UIImage]) async throws {
        guard await requestAuthorization() else {
            throw PhotosServiceError.accessDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        } catch {
            throw PhotosServiceError.saveFailed(error)
        }
    }
}
