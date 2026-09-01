import SwiftUI

/// Root view that decides whether to show the onboarding flow or the main scanning interface
/// based on whether initial setup has been completed.
/// Displays a launch screen briefly before transitioning to the main content.
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showLaunchScreen = true

    var body: some View {
        if showLaunchScreen {
            LaunchScreenView()
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showLaunchScreen = false
                        }
                    }
                }
        } else {
            if settings.isSetupComplete {
                MainView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
