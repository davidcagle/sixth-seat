import SwiftUI

/// Stub destination for the Chip Shop route. Real IAP integration with
/// bundle cards, pricing, and StoreKit ships in Session 16. The stub
/// upgrade in Session 12b adds an explanatory line and a back-to-menu
/// button so the in-game second-bust modal has a non-broken landing
/// page to route to.
struct ChipShopView: View {

    @Environment(\.dismiss) private var dismiss

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                Text("Chip Shop")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("ChipShop.Title")

                Text("Chip bundles coming soon.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityIdentifier("ChipShop.ComingSoon")

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Back to Menu")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .accessibilityIdentifier("ChipShop.BackToMenu")
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Chip Shop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ChipShopView() }
}
