import SwiftUI
import SixthSeat

/// Tier 2 / Tier 3 hand-result ceremony. Displays the qualifying hand
/// name(s) and the headline payout. Used as a centered overlay above
/// the table felt while the chips are still in their pre-resolution
/// positions.
struct CeremonyView: View {
    let state: CeremonyState
    /// True for Tier 3 (.big) — bumps the typography and adds a subtle
    /// shimmer/glow. Tier 2 keeps it tighter.
    let isBigTier: Bool

    @State private var pulseScale: CGFloat = 0.85

    var body: some View {
        VStack(spacing: isBigTier ? 14 : 10) {
            handNamesRow
            payoutLine
        }
        .padding(.horizontal, isBigTier ? 28 : 20)
        .padding(.vertical, isBigTier ? 18 : 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor.opacity(0.65), lineWidth: isBigTier ? 2 : 1.5)
                )
                .shadow(color: borderColor.opacity(isBigTier ? 0.55 : 0.35),
                        radius: isBigTier ? 16 : 8)
        )
        .scaleEffect(pulseScale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                pulseScale = 1.0
            }
        }
    }

    // MARK: - Hand names

    @ViewBuilder
    private var handNamesRow: some View {
        if state.showsPlayerHand && state.showsDealerHand {
            HStack(spacing: 18) {
                handNameLabel(
                    "YOU",
                    rank: state.playerHand,
                    highlighted: state.isPlayerWin && !state.isPush
                )
                Text("vs")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                handNameLabel(
                    "DEALER",
                    rank: state.dealerHand,
                    highlighted: state.isDealerWin && !state.isPush
                )
            }
        } else if state.showsPlayerHand {
            handNameLabel(
                "YOU",
                rank: state.playerHand,
                highlighted: state.isPlayerWin && !state.isPush,
                centered: true
            )
        } else if state.showsDealerHand {
            handNameLabel(
                "DEALER",
                rank: state.dealerHand,
                highlighted: state.isDealerWin && !state.isPush,
                centered: true
            )
        }
    }

    private func handNameLabel(
        _ owner: String,
        rank: HandRank,
        highlighted: Bool,
        centered: Bool = false
    ) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 2) {
            Text(owner)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text(rankName(rank))
                .font(.system(size: isBigTier ? 26 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? Color.tableGold : .white.opacity(0.85))
                .shadow(color: highlighted ? Color.tableGold.opacity(0.55) : .clear,
                        radius: highlighted ? 6 : 0)
        }
    }

    // MARK: - Payout line

    @ViewBuilder
    private var payoutLine: some View {
        if state.isPush {
            Text("PUSH")
                .font(.system(size: isBigTier ? 26 : 20, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.yellow.opacity(0.85))
        } else {
            let amount = state.payoutAmount
            let prefix = amount >= 0 ? "+" : "-"
            Text("\(prefix)$\(abs(amount))")
                .font(.system(size: isBigTier ? 30 : 24, weight: .heavy, design: .rounded))
                .foregroundStyle(payoutColor)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Palette

    private var borderColor: Color {
        if state.isPush { return .yellow }
        return state.useGoldTreatment ? Color.tableGold : Color(red: 0.7, green: 0.18, blue: 0.18)
    }

    private var payoutColor: Color {
        if state.isPush { return .yellow }
        return state.useGoldTreatment ? Color.tableGold : Color(red: 0.95, green: 0.4, blue: 0.4)
    }

    private func rankName(_ rank: HandRank) -> String {
        switch rank {
        case .highCard:      return "High Card"
        case .pair:          return "Pair"
        case .twoPair:       return "Two Pair"
        case .threeOfAKind:  return "Three of a Kind"
        case .straight:      return "Straight"
        case .flush:         return "Flush"
        case .fullHouse:     return "Full House"
        case .fourOfAKind:   return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush:    return "Royal Flush"
        }
    }
}

/// Tier 4 jackpot ceremony — full-screen, larger typography, optional
/// "tap to continue" prompt once the lock-in window has expired.
struct JackpotCeremonyView: View {
    let state: CeremonyState
    let advanceEnabled: Bool

    @State private var titleScale: CGFloat = 0.6
    @State private var sparkleOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Full-screen scrim — taps land on the parent gesture, which
            // routes to skipToSettled (gated by advanceEnabled in the VM).
            Color.black.opacity(0.78).ignoresSafeArea()

            // Sparkle ring — purely decorative.
            sparkleField
                .opacity(sparkleOpacity)

            VStack(spacing: 22) {
                Text(state.isPush ? "PUSH" : (state.useGoldTreatment ? "JACKPOT!" : "DEALER JACKPOT"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(headlineColor.opacity(0.85))

                Text(rankName(highlightedRank))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(headlineColor)
                    .shadow(color: headlineColor.opacity(0.7), radius: 18)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .scaleEffect(titleScale)

                if state.showsPlayerHand && state.showsDealerHand && state.playerTier != state.dealerTier {
                    // Both qualify but only one is jackpot tier — show the
                    // other side as a smaller subhead.
                    Text(otherSideLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                payoutLine

                if advanceEnabled {
                    Text("Tap to continue")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 6)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                titleScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.1)) {
                sparkleOpacity = 1.0
            }
        }
    }

    @ViewBuilder
    private var payoutLine: some View {
        if state.isPush {
            EmptyView()
        } else {
            let amount = state.payoutAmount
            let prefix = amount >= 0 ? "+" : "-"
            Text("\(prefix)$\(abs(amount))")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(payoutColor)
                .shadow(color: payoutColor.opacity(0.6), radius: 14)
                .contentTransition(.numericText())
        }
    }

    /// Whose hand we feature in the headline. The jackpot side wins when
    /// tiers differ; if both are Tier 4, prefer the player's hand for the
    /// headline (showing the dealer side underneath).
    private var highlightedRank: HandRank {
        if state.playerTier >= state.dealerTier {
            return state.playerHand
        }
        return state.dealerHand
    }

    private var otherSideLabel: String {
        if state.playerTier >= state.dealerTier && state.showsDealerHand {
            return "Dealer: \(rankName(state.dealerHand))"
        }
        if state.dealerTier > state.playerTier && state.showsPlayerHand {
            return "You: \(rankName(state.playerHand))"
        }
        return ""
    }

    private var headlineColor: Color {
        if state.isPush { return .yellow }
        return state.useGoldTreatment ? Color.tableGold : Color(red: 0.95, green: 0.4, blue: 0.4)
    }

    private var payoutColor: Color {
        headlineColor
    }

    private var sparkleField: some View {
        // 12 small dots arranged in a ring — cheap "sparkle" stand-in
        // until real art drops in.
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.38
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let angle = (Double(i) / 12.0) * 2.0 * .pi
                    Circle()
                        .fill(headlineColor.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .position(
                            x: center.x + radius * CGFloat(cos(angle)),
                            y: center.y + radius * CGFloat(sin(angle))
                        )
                }
            }
        }
    }

    private func rankName(_ rank: HandRank) -> String {
        switch rank {
        case .highCard:      return "High Card"
        case .pair:          return "Pair"
        case .twoPair:       return "Two Pair"
        case .threeOfAKind:  return "Three of a Kind"
        case .straight:      return "Straight"
        case .flush:         return "Flush"
        case .fullHouse:     return "Full House"
        case .fourOfAKind:   return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush:    return "Royal Flush"
        }
    }
}

extension Color {
    /// Brand gold reserved for player-win ceremonies (decision 2). Tuned
    /// to read cleanly against the felt and against the muted red used
    /// for dealer-win ceremonies.
    static let tableGold = Color(red: 1.0, green: 0.83, blue: 0.27)
}
