import SwiftUI

/// In-game bust flash modal. Presented as a full-screen dim overlay over
/// `GameTableView` when the player's balance lands at zero after a hand
/// resolves. Two variants:
///
/// - `.firstBust` announces the 2,500-chip second-chance gift and
///   auto-dismisses after 5 seconds (or on tap).
/// - `.secondBust` informs the player they're tapped out and routes to
///   the Chip Shop via an explicit button.
struct BustFlashView: View {

    let kind: BustModalKind
    let onDismiss: () -> Void
    let onVisitChipShop: () -> Void

    var body: some View {
        ZStack {
            // Dim background absorbs taps; first-bust dismisses on dim
            // tap, second-bust requires the explicit Chip Shop button or
            // a tap on the dim to drop the modal in place.
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .accessibilityIdentifier("BustFlash.Dim")

            VStack(spacing: 18) {
                Text(BustFlashView.headline(for: kind))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("BustFlash.Headline")

                Text(BustFlashView.subline(for: kind))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                button
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.12, green: 0.18, blue: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 6)
            .accessibilityIdentifier("BustFlash.Card")
        }
    }

    @ViewBuilder
    private var button: some View {
        switch kind {
        case .firstBust:
            Button(action: onDismiss) {
                Text("Continue")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow))
            }
            .accessibilityIdentifier("BustFlash.Continue")
        case .secondBust:
            Button(action: onVisitChipShop) {
                Text("Visit Chip Shop")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow))
            }
            .accessibilityIdentifier("BustFlash.VisitChipShop")
        }
    }

    /// First line of modal copy. Exposed for unit tests so the brand-voiced
    /// strings remain locked in code without standing up a UI test runner.
    static func headline(for kind: BustModalKind) -> String {
        switch kind {
        case .firstBust:  return "Pit boss spots you 2,500 chips."
        case .secondBust: return "Tapped out."
        }
    }

    /// Second line of modal copy. Same exposure rationale as `headline`.
    static func subline(for kind: BustModalKind) -> String {
        switch kind {
        case .firstBust:  return "Have another go."
        case .secondBust: return "Hit the chip shop to buy back in."
        }
    }
}

#Preview("First bust") {
    BustFlashView(kind: .firstBust, onDismiss: {}, onVisitChipShop: {})
        .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}

#Preview("Second bust") {
    BustFlashView(kind: .secondBust, onDismiss: {}, onVisitChipShop: {})
        .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
