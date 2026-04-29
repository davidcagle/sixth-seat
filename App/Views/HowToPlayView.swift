import SwiftUI
import SixthSeat

/// Single scrollable rules reference. Sections cover the goal, the bets,
/// the hand flow, dealer qualification, the two paytables, and a brief
/// note on Pairs Plus.
///
/// Paytable rows source their multipliers from `UTHRules.blindPaytable`
/// and `UTHRules.tripsPaytable` — the same constants the engine uses to
/// resolve hands. This eliminates spec/UI drift: changing a paytable
/// multiplier in one place updates both resolution and display.
struct HowToPlayView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(title: "The Goal", body: HowToPlayCopy.goal)

                betsSection

                handFlowSection

                section(title: "Dealer Qualification", body: HowToPlayCopy.dealerQualification)

                paytableSection(
                    title: "Blind Bonus Payouts",
                    rows: HowToPlayCopy.blindRows,
                    accessibilityIdentifier: "HowToPlay.BlindPaytable"
                )

                paytableSection(
                    title: "Trips Side Bet Payouts",
                    rows: HowToPlayCopy.tripsRows,
                    accessibilityIdentifier: "HowToPlay.TripsPaytable"
                )

                section(title: "About Pairs Plus", body: HowToPlayCopy.pairsPlusNote)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Generic section

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(body)
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Bets

    private var betsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The Bets")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            ForEach(HowToPlayCopy.bets, id: \.name) { bet in
                VStack(alignment: .leading, spacing: 2) {
                    Text(bet.name)
                        .font(.system(size: 15, weight: .semibold))
                    Text(bet.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Hand Flow

    private var handFlowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hand Flow")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            ForEach(Array(HowToPlayCopy.handFlow.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .frame(width: 24, alignment: .trailing)
                    Text(step)
                        .font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Paytable

    private func paytableSection(
        title: String,
        rows: [HowToPlayCopy.PaytableRow],
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack {
                        Text(row.handName)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(row.payout)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.04) : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

// MARK: - Static copy + paytable rendering

/// Static rules-screen copy plus the formatted paytable rows. Paytable
/// rows are derived from `UTHRules.blindPaytable` and `UTHRules.tripsPaytable`
/// so the engine's payout source-of-truth is the same source the UI reads.
enum HowToPlayCopy {

    static let goal = """
    Beat the dealer's 5-card hand using your two hole cards plus the five community cards. You're playing against the house, not other players at the table.
    """

    struct Bet {
        let name: String
        let description: String
    }

    static let bets: [Bet] = [
        Bet(name: "Ante", description: "Required. Sets the table."),
        Bet(name: "Blind", description: "Required, equal to the Ante. Pays a bonus on a straight or better."),
        Bet(name: "Play", description: "Your one main decision. Bet 3× or 4× before the flop, 2× after the flop, 1× after the river — or fold."),
        Bet(name: "Trips", description: "Optional side bet. Pays on three of a kind or better regardless of the dealer's hand.")
    ]

    static let handFlow = [
        "Place Ante and Blind. Optionally place Trips.",
        "You and the dealer each receive two hole cards face down.",
        "Pre-flop: bet 3× or 4× the Ante (Play), or check.",
        "Dealer reveals the three flop cards.",
        "Post-flop: if you haven't bet, you may bet 2× Ante or check.",
        "Dealer reveals the turn and river.",
        "Post-river: if you still haven't bet, bet 1× Ante or fold.",
        "Dealer reveals their hole cards. Dealer must have a pair or better to qualify.",
        "Hands are compared. Bets are resolved."
    ]

    static let dealerQualification = """
    The dealer must have a pair or better to qualify. If the dealer does not qualify, the Ante pushes (your stake is returned), the Play bet still pays 1:1, and the Blind resolves on its own paytable.
    """

    static let pairsPlusNote = """
    6th Seat does not offer the Pairs Plus side bet. Pairs Plus is a common table variant in some casinos but is not part of the standard Las Vegas Ultimate Texas Hold'em rules we follow.
    """

    // MARK: Paytable rendering

    struct PaytableRow {
        let handName: String
        let payout: String
        /// Underlying rank, retained so tests can verify the row order
        /// matches the engine's paytable contents.
        let rank: HandRank?
    }

    /// Paytable rank order, strongest-to-weakest, for display purposes.
    /// Matches the order Vegas casinos print on the felt.
    private static let displayOrder: [HandRank] = [
        .royalFlush,
        .straightFlush,
        .fourOfAKind,
        .fullHouse,
        .flush,
        .straight,
        .threeOfAKind
    ]

    /// Rows for the Blind bonus paytable. Hands below `straight` push, so
    /// a "Push" row is appended after the listed multipliers — this is the
    /// catch-all for "you won the hand but not with a strong enough rank
    /// to earn the bonus."
    static var blindRows: [PaytableRow] {
        var rows: [PaytableRow] = displayOrder.compactMap { rank in
            guard let multiplier = UTHRules.blindPaytable[rank] else { return nil }
            return PaytableRow(
                handName: handDisplayName(rank),
                payout: formatMultiplier(multiplier),
                rank: rank
            )
        }
        rows.append(PaytableRow(handName: "All other wins", payout: "Push", rank: nil))
        return rows
    }

    /// Rows for the Trips side-bet paytable. No "push" row — Trips wins or
    /// loses, never pushes.
    static var tripsRows: [PaytableRow] {
        displayOrder.compactMap { rank in
            guard let multiplier = UTHRules.tripsPaytable[rank] else { return nil }
            return PaytableRow(
                handName: handDisplayName(rank),
                payout: formatMultiplier(multiplier),
                rank: rank
            )
        }
    }

    private static func handDisplayName(_ rank: HandRank) -> String {
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

    /// Formats a paytable multiplier as a Vegas-style ratio. Whole numbers
    /// render as "N:1"; the half-payout `1.5` (Blind paytable Flush) renders
    /// as "3:2" because that's how it prints on the felt.
    static func formatMultiplier(_ multiplier: Double) -> String {
        if multiplier == 1.5 { return "3:2" }
        if multiplier == multiplier.rounded() {
            return "\(Int(multiplier)):1"
        }
        // Generic non-integer fallback. Not currently exercised by either
        // paytable, but kept so a future paytable tweak doesn't crash.
        return String(format: "%.2f:1", multiplier)
    }
}

#Preview {
    NavigationStack { HowToPlayView() }
}
