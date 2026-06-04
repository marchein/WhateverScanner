import SwiftUI

/// Root view that decides whether to show the onboarding flow or the main scanning interface
/// based on whether initial setup has been completed.
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if settings.isSetupComplete {
            MainView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
