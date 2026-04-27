import SwiftUI

/// Stub destination for the Main Menu's How to Play route. Real
/// rules content lands later, likely as a static rules screen.
struct HowToPlayView: View {
    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("How to Play")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("HowToPlay.Title")
                Text("Coming soon")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HowToPlayView() }
}
