import SwiftUI

/// Placeholder betting zone. Shows a label and the current wager amount
/// (or "—" if empty). Tappable — forwards the intent back via `onTap`.
///
/// `animation` drives chip-resolution motion. The zone's "$X" pill is
/// the chip representation in V1 — it pulses, slides toward the tray
/// or dealer, fades, or doubles + slides on win.
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
            // The base bet zone — label + amount pill — plus a "matched"
            // ghost chip during the win pulse so the player sees their
            // payout materialize next to the original wager.
            zoneBody

            if animation == .winMatched && amount > 0 {
                amountPill
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
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(1)
            amountPill
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(8)
        .background(
            Circle()
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            Circle()
                .strokeBorder(
                    isActive ? Color.yellow : Color.white.opacity(0.5),
                    lineWidth: isActive ? 2 : 1
                )
        )
    }

    private var amountPill: some View {
        Text(amount > 0 ? "$\(amount)" : "—")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
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
