import SwiftUI
import SixthSeat

/// One row in the post-resolution payout breakdown — the engine's
/// `BetOutcome` plus stake plus the bet's name, flattened into the
/// strings the view renders. Built once per resolved bet zone in
/// `PayoutBreakdownView`'s `init`.
struct PayoutLine: Equatable {
    enum Result: Equatable {
        case win
        case loss
        case push
    }

    let label: String          // "ANTE", "BLIND", "PLAY", "TRIPS"
    let result: Result
    let amount: Double         // signed: profit/loss in chips
    let payoutRatio: String?   // "3:2", "6:1", or nil for 1:1 / push / loss

    /// Pure constructor — no UI dependencies, exposed for unit tests
    /// that want to verify line composition without rendering SwiftUI.
    static func make(label: String, outcome: BetOutcome, stake: Double) -> PayoutLine? {
        guard stake > 0 else { return nil }
        switch outcome {
        case .win:
            return PayoutLine(label: label, result: .win, amount: stake, payoutRatio: nil)
        case .lose:
            return PayoutLine(label: label, result: .loss, amount: -stake, payoutRatio: nil)
        case .push:
            return PayoutLine(label: label, result: .push, amount: 0, payoutRatio: nil)
        case .blindBonus(let multiplier):
            // The Trips zone uses .blindBonus for losses too? No — the
            // engine returns `.lose` for sub-three-of-a-kind. So if we
            // see a multiplier, the bet won.
            let amount = stake * multiplier
            // Some Blind/Trips wins are 1:1 (the Blind on a winning
            // straight pays even money) — don't render "(1:1)" since
            // that's the implicit baseline.
            let ratio = multiplier == 1.0 ? nil : Self.formatRatio(multiplier)
            return PayoutLine(label: label, result: .win, amount: amount, payoutRatio: ratio)
        }
    }

    /// Formats a paytable multiplier as the parenthetical ratio shown on
    /// the breakdown line. Half-integer multipliers (Blind flush 1.5×)
    /// render as "3:2"; integer multipliers as "N:1".
    static func formatRatio(_ multiplier: Double) -> String {
        if multiplier == 1.5 { return "3:2" }
        // Detect other rational fractions of the form X:2, then fall
        // back to N:1 for integer multipliers. The current paytables
        // use only integer values plus the single 1.5 case.
        let rounded = multiplier.rounded()
        if abs(multiplier - rounded) < 0.0001 {
            return "\(Int(rounded)):1"
        }
        // Generic X:Y formatter for any future half-integer entries.
        let scaled = multiplier * 2
        let scaledRounded = scaled.rounded()
        if abs(scaled - scaledRounded) < 0.0001 {
            return "\(Int(scaledRounded)):2"
        }
        return String(format: "%.1f:1", multiplier)
    }
}

/// Pure builder for the breakdown rows. Lifted out of the SwiftUI view
/// so tests can verify the row composition without rendering.
enum PayoutBreakdownLogic {

    /// Builds the visible lines from a resolved hand, applying the spec's
    /// "show only what was placed" rule. PLAY hides on a fold even if
    /// the bet is non-zero (the engine doesn't move chips on a fold).
    static func lines(from result: HandResult, anteBet: Int, blindBet: Int, playBet: Int, tripsBet: Int, playerFolded: Bool) -> [PayoutLine] {
        var lines: [PayoutLine] = []
        if let line = PayoutLine.make(label: "ANTE", outcome: result.anteOutcome, stake: Double(anteBet)) {
            lines.append(line)
        }
        if let line = PayoutLine.make(label: "BLIND", outcome: result.blindOutcome, stake: Double(blindBet)) {
            lines.append(line)
        }
        if !playerFolded, let line = PayoutLine.make(label: "PLAY", outcome: result.playOutcome, stake: Double(playBet)) {
            lines.append(line)
        }
        if let line = PayoutLine.make(label: "TRIPS", outcome: result.tripsOutcome, stake: Double(tripsBet)) {
            lines.append(line)
        }
        return lines
    }

    /// Total of the signed amounts across the visible lines. Equal to
    /// `result.totalNet` when nothing is filtered out (e.g. PLAY shown);
    /// when PLAY is hidden by a fold, the engine's playNet contribution
    /// is by definition zero and the totals still match.
    static func totalNet(of lines: [PayoutLine]) -> Double {
        lines.reduce(0) { $0 + $1.amount }
    }
}

/// Replaces the post-resolution headline payout number with a per-bet
/// breakdown plus total. Renders only the bets the player actually placed
/// (per Session 15b spec). Static — no roll-in animation.
struct PayoutBreakdownView: View {

    let lines: [PayoutLine]
    let totalNet: Double

    init(result: HandResult, anteBet: Int, blindBet: Int, playBet: Int, tripsBet: Int, playerFolded: Bool) {
        let computed = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: anteBet,
            blindBet: blindBet,
            playBet: playBet,
            tripsBet: tripsBet,
            playerFolded: playerFolded
        )
        self.lines = computed
        self.totalNet = PayoutBreakdownLogic.totalNet(of: computed)
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(lines, id: \.label) { line in
                row(line)
            }
            Divider()
                .background(Color.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            totalRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.45))
        )
        .accessibilityIdentifier("PayoutBreakdown")
    }

    @ViewBuilder
    private func row(_ line: PayoutLine) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(line.label) \(verb(for: line.result))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            HStack(spacing: 6) {
                Text(amountText(line))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(for: line.result))
                if let ratio = line.payoutRatio {
                    Text("(\(ratio))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .accessibilityIdentifier("PayoutBreakdown.\(line.label)")
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TOTAL")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white)
            Spacer()
            Text(totalText)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(totalColor)
        }
        .accessibilityIdentifier("PayoutBreakdown.Total")
    }

    private func verb(for result: PayoutLine.Result) -> String {
        switch result {
        case .win:  return "WIN"
        case .loss: return "LOSS"
        case .push: return "PUSH"
        }
    }

    private func color(for result: PayoutLine.Result) -> Color {
        switch result {
        case .win:  return .green
        case .loss: return .red
        case .push: return .yellow
        }
    }

    private func amountText(_ line: PayoutLine) -> String {
        let n = Int(line.amount.rounded())
        switch line.result {
        case .win:  return "+$\(n)"
        case .loss: return "-$\(-n)"
        case .push: return "PUSH"
        }
    }

    private var totalText: String {
        let n = Int(totalNet.rounded())
        if n > 0 { return "+$\(n)" }
        if n < 0 { return "-$\(-n)" }
        return "Push"
    }

    private var totalColor: Color {
        if totalNet > 0 { return .green }
        if totalNet < 0 { return .red }
        return .yellow
    }
}
