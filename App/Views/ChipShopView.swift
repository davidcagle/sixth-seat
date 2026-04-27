import SwiftUI

/// Stub destination for the Main Menu's Chip Shop route. Real IAP
/// integration lands in Session 16.
struct ChipShopView: View {
    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Chip Shop")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("ChipShop.Title")
                Text("Coming soon")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .navigationTitle("Chip Shop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ChipShopView() }
}
