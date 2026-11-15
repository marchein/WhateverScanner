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
        try resolveFolderCheckingStaleness(from: bookmark).url
    }

    /// Writes data to a file, using the bookmarked folder if one is set, otherwise
    /// falling back to the app's own Documents folder. An existing file with the same
    /// name is never overwritten; a numeric suffix is appended instead.
    /// - Parameters:
    ///   - data: The file data to write.
    ///   - filename: The destination filename.
    ///   - bookmark: The security-scoped bookmark for the destination folder, if any.
    /// - Returns: A refreshed bookmark if the stored one was stale and should be
    ///   replaced in the settings, otherwise `nil`.
    /// - Throws: `FilesServiceError` if the folder cannot be accessed or the write fails.
    @discardableResult
    static func save(data: Data, filename: String, bookmark: Data?) throws -> Data? {
        guard let bookmark else {
            try write(data, to: uniqueFileURL(in: defaultFolderURL, filename: filename))
            return nil
        }

        let (folderURL, isStale) = try resolveFolderCheckingStaleness(from: bookmark)
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw FilesServiceError.accessDenied
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        try write(data, to: uniqueFileURL(in: folderURL, filename: filename))

        // A stale bookmark still resolves, but should be re-created while we have
        // access, otherwise it may stop working entirely (e.g. after the folder was
        // moved or the file provider was updated).
        guard isStale else { return nil }
        return try? folderURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Returns a URL for `filename` inside `folder` that doesn't exist yet, appending
    /// " 2", " 3", … to the base name if needed. Never returns an occupied URL, so
    /// an existing scan is never replaced.
    static func uniqueFileURL(in folder: URL, filename: String) -> URL {
        let candidate = folder.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let url = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }

    // MARK: - Private

    private static func resolveFolderCheckingStaleness(from bookmark: Data) throws -> (url: URL, isStale: Bool) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw FilesServiceError.bookmarkResolutionFailed(error)
        }
    }

    private static func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Log.export.error("Writing file failed: \(error.localizedDescription, privacy: .private)")
            throw FilesServiceError.writeFailed(error)
        }
    }
}
