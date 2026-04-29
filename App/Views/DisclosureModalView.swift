import SwiftUI
import SixthSeat

/// Apple 4.3 simulated-gambling disclosure copy. Surfaced as a one-time
/// modal on first launch and as informational copy in the Settings screen.
/// Centralized here so the two surfaces never drift.
enum DisclosureCopy {
    static let title = "6th Seat is for entertainment only."

    static let body = """
    This app does not offer real-money gambling, prizes, or the opportunity to win anything of monetary value. Virtual chips have no cash value and cannot be redeemed or exchanged.

    Practice or success at this game does not imply future success at real-money gambling.
    """
}

/// First-launch disclosure modal. Presents over the Main Menu when
/// `PersistenceKeys.hasSeenDisclosure` is false; tapping "I Understand"
/// flips the flag and dismisses the modal. Non-dismissible by background
/// tap or swipe — the button is the only exit.
struct DisclosureModalView: View {

    @Binding var isPresented: Bool
    @AppStorage(PersistenceKeys.hasSeenDisclosure) private var hasSeenDisclosure: Bool = false

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(DisclosureCopy.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Disclosure.Title")

                Text(DisclosureCopy.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("Disclosure.Body")

                Spacer()

                Button(action: acknowledge) {
                    Text("I Understand")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow)
                        )
                }
                .accessibilityIdentifier("Disclosure.Acknowledge")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .interactiveDismissDisabled(true)
    }

    private func acknowledge() {
        hasSeenDisclosure = true
        isPresented = false
    }
}

#Preview {
    DisclosureModalView(isPresented: .constant(true))
}
