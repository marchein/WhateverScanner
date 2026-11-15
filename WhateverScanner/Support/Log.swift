import Foundation
import os

/// Central `os.Logger` instances for the app.
///
/// Messages end up in the unified logging system (Console.app, sysdiagnose) and
/// are therefore available when diagnosing problems reported by TestFlight
/// testers, without shipping any third-party analytics SDK. User content
/// (document text, server credentials, filenames) must never be logged with
/// `privacy: .public`.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "de.marc-hein.whateverscanner"

    /// Scanning, PDF generation and OCR.
    static let scan = Logger(subsystem: subsystem, category: "scan")
    /// Saving to Photos/Files and uploading to WebDAV/SMB.
    static let export = Logger(subsystem: subsystem, category: "export")
    /// Settings persistence and the Keychain.
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
