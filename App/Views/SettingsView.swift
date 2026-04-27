import SwiftUI

/// Stub destination for the Main Menu's Settings route. Real
/// settings UI (audio, haptics, Apple 4.3 disclosures, reset chips)
/// lands in Session 15.
struct SettingsView: View {
    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Settings")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("Settings.Title")
                Text("Coming soon")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
