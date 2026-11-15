import Foundation

/// Builds the filename used when saving/uploading a scanned PDF.
enum ScanFilename {

    /// Maximum length of the name part (without date and extension). Keeps the
    /// full filename well below the 255-byte limit of most file systems/servers.
    static let maxNameLength = 80

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Fixed locale/calendar so the filename format doesn't depend on the
        // user's region settings (e.g. Buddhist or Japanese calendars, 12h clock).
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    /// Creates a filename like `Invoice ACME_2024-05-01_12-30-00.pdf`.
    /// - Parameters:
    ///   - name: The user-facing document name; falls back to "Scan" when empty.
    ///   - date: The date to embed in the filename.
    /// - Returns: A filename that's safe for Files, WebDAV and SMB.
    static func make(name: String, date: Date) -> String {
        let safeName = sanitize(name)
        return "\(safeName.isEmpty ? "Scan" : safeName)_\(dateFormatter.string(from: date)).pdf"
    }

    /// Removes characters that are invalid in filenames on common file systems
    /// (including SMB/Windows shares), control characters, and leading dots.
    /// - Parameter name: The raw name.
    /// - Returns: The sanitized, trimmed and length-limited name.
    static func sanitize(_ name: String) -> String {
        var invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        invalid.formUnion(.controlCharacters)
        invalid.formUnion(.newlines)

        var result = name
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Leading dots would create hidden files; trailing dots/spaces are invalid on Windows.
        while result.hasPrefix(".") { result.removeFirst() }
        if result.count > maxNameLength {
            result = String(result.prefix(maxNameLength))
        }
        while result.hasSuffix(".") || result.hasSuffix(" ") { result.removeLast() }
        return result
    }
}
