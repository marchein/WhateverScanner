import SwiftUI

/// The main entry point for the WhateverScanner application.
/// Initializes the shared `AppSettings` and injects it into the SwiftUI environment.
@main
struct WhateverScannerApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
