import SwiftUI
import SixthSeat

/// Betting zone. Renders the label, a circular bet area (with a chip
/// stack inside when there's a wager), and the dollar amount below.
/// Tappable — forwards the intent back via `onTap`.
///
/// Chip-stack visualization (Session 21) reads
/// `ChipDecomposition.bestFit(for: amount)` and routes through
/// `ChipStackView`. When `amount == 0`, no chip stack renders and the
/// amount label collapses to "—" inside the empty circle.
///
/// `animation` drives chip-resolution motion. The whole zone — chip
/// stack and labels — scales, slides, and fades together so resolution
/// motion stays coherent.
struct BetZoneView: View {
    let label: String
    let amount: Int
    var isActive: Bool = false
    /// When true, the zone renders dimmed and ignores taps. Used by the
    /// Session 12d affordability gates to signal that a tappable zone
    /// (Trips) cannot accept input at the current balance / Ante.
    var isDisabled: Bool = false
    var animation: BetZoneAnimation = .none
    var onTap: (() -> Void)? = nil

    private let circleDiameter: CGFloat = 60

    var body: some View {
        let pulseScale: CGFloat = (animation == .pulsing) ? 1.18 : 1.0
        let slideY: CGFloat = {
            switch animation {
            case .slidingDown: return 220   // toward player tray (bottom)
            case .slidingUp:   return -220  // toward dealer (top)
            default:           return 0
            }
        }()
        let motionOpacity: Double = {
            switch animation {
            case .slidingDown, .slidingUp: return 0
            default:                       return 1
            }
        }()
        // The disabled dim multiplies into the motion opacity so the
        // slide-out fade still resolves to 0 cleanly.
        let opacity = motionOpacity * (isDisabled ? 0.45 : 1.0)

        let content = ZStack {
            zoneBody

            if animation == .winMatched && amount > 0 {
                amountLabel
                    .offset(x: 28)
                    .scaleEffect(0.9)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .scaleEffect(pulseScale)
        .offset(y: slideY)
        .opacity(opacity)

        if let onTap, !isDisabled {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var zoneBody: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(1)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isActive ? Color.yellow : Color.white.opacity(0.5),
                                lineWidth: isActive ? 2 : 1
                            )
                    )

                if amount > 0, let chip = ChipDecomposition.bestFit(for: amount) {
                    ChipStackView(
                        denomination: chip.denomination,
                        count: chip.count,
                        diameter: circleDiameter - 8
                    )
                    .accessibilityIdentifier("BetZone.ChipStack.\(label)")
                }
            }
            .frame(width: circleDiameter, height: circleDiameter)

            amountLabel
        }
    }

    private var amountLabel: some View {
        Text(amount > 0 ? "$\(amount)" : "—")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(amount > 0 ? Color.yellow : .white.opacity(0.6))
    }
}

#Preview {
    HStack(spacing: 16) {
        BetZoneView(label: "TRIPS", amount: 0)
        BetZoneView(label: "ANTE",  amount: 10, isActive: true)
        BetZoneView(label: "BLIND", amount: 10)
        BetZoneView(label: "PLAY",  amount: 40)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
