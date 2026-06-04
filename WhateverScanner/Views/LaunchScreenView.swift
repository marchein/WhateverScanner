import SwiftUI

/// A splash screen displayed briefly when the app launches,
/// showing the app icon and name before transitioning to the main content.
struct LaunchScreenView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "document.viewfinder.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
            Text("WhateverScanner")
                .font(.title)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LaunchScreenView()
}
