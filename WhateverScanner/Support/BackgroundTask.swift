import UIKit

/// Helper that keeps the app running for a short while after it moves to the
/// background, so that an in-flight save/upload isn't suspended halfway through
/// when the user switches apps or locks the device.
enum BackgroundTask {

    /// Runs `operation` wrapped in a `UIApplication` background task.
    /// - Parameters:
    ///   - name: A debug name for the background task.
    ///   - operation: The asynchronous work to perform.
    /// - Returns: Whatever `operation` returns.
    @MainActor
    static func run<T>(named name: String, _ operation: () async throws -> T) async rethrows -> T {
        let token = Token()
        token.identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Time is up: end the task so iOS doesn't terminate the app.
            // Pending network requests will fail and be reported as errors.
            MainActor.assumeIsolated {
                Log.export.notice("Background time expired for \(name, privacy: .public)")
                token.end()
            }
        }
        defer { token.end() }
        return try await operation()
    }

    /// Holds the background task identifier so it can be ended exactly once,
    /// either when the work finishes or when the system's expiration handler fires.
    @MainActor
    private final class Token {
        var identifier: UIBackgroundTaskIdentifier = .invalid

        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
}
