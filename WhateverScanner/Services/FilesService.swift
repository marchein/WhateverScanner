import Foundation

// MARK: - Errors

/// Errors that can occur while saving files to a Files app folder.
enum FilesServiceError: LocalizedError {
    /// The security-scoped bookmark could not be resolved.
    case bookmarkResolutionFailed(Error)
    /// Access to the security-scoped resource was denied.
    case accessDenied
    /// Writing the file to disk failed.
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .bookmarkResolutionFailed(let error):
            return String(localized: "Could not access the selected folder: \(error.localizedDescription)")
        case .accessDenied:
            return String(localized: "Access to the selected folder was denied.")
        case .writeFailed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Service

/// Service responsible for writing scanned PDFs into a folder in the Files app.
/// When the user has picked a folder, a security-scoped bookmark is used to access
/// it persistently; otherwise files are written to the app's own Documents folder,
/// which is visible in the Files app under "On My iPhone/iPad > WhateverScanner".
enum FilesService {

    /// The app's own Documents directory, used as the default Files destination
    /// when the user hasn't picked a custom folder.
    static var defaultFolderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Resolves a security-scoped bookmark into a folder URL.
    /// - Parameter bookmark: The bookmark data previously created from a folder picker selection.
    /// - Returns: The resolved folder URL.
    /// - Throws: `FilesServiceError.bookmarkResolutionFailed` if resolution fails.
    static func resolveFolder(from bookmark: Data) throws -> URL {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            throw FilesServiceError.bookmarkResolutionFailed(error)
        }
    }

    /// Writes data to a file, using the bookmarked folder if one is set, otherwise
    /// falling back to the app's own Documents folder.
    /// - Parameters:
    ///   - data: The file data to write.
    ///   - filename: The destination filename.
    ///   - bookmark: The security-scoped bookmark for the destination folder, if any.
    /// - Throws: `FilesServiceError` if the folder cannot be accessed or the write fails.
    static func save(data: Data, filename: String, bookmark: Data?) throws {
        guard let bookmark else {
            let fileURL = defaultFolderURL.appendingPathComponent(filename)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                throw FilesServiceError.writeFailed(error)
            }
            return
        }

        let folderURL = try resolveFolder(from: bookmark)
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw FilesServiceError.accessDenied
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let fileURL = folderURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw FilesServiceError.writeFailed(error)
        }
    }
}
