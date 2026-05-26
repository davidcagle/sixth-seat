#if DEBUG

import Foundation

/// Preset hands the Session 18c debug-deal affordance can inject before
/// the next `deal()`. Each case maps to a 9-card sequence consumed by
/// `GameState.deal()` in the order: player hole × 2, dealer hole × 2,
/// flop × 3, turn, river. Used solely by the hidden DebugMenuView path
/// to reproduce the three ⏳ items from Session 18a's phone-test pass.
///
/// Never compiled into Release builds.
public enum DebugScenario: String, CaseIterable, Sendable {
    /// Dealer reveals high-card-only and fails to qualify (less than a
    /// pair). Verifies the dealer-doesn't-qualify code path.
    case dealerDoesNotQualify

    /// Player makes a flush on the river. Verifies a community-board
    /// progression where the winning hand only completes on the last
    /// community card.
    case playerFlushOnRiver

    /// Player and dealer share the identical 5-card straight, producing
    /// a push on the main hand. With a Trips bet placed the player can
    /// verify that Trips pays out independent of the main-bet outcome.
    case push

    /// Reproduces the Session 32 on-device hand: player pairs aces while
    /// the dealer holds J-high (no qualify). Used to regression-cover the
    /// per-zone settlement of dealer-no-qualify + player-pair: Ante must
    /// push, Blind must push (pair < straight floor), Play must win 1:1.
    case dealerNoQualifyPlayerPair

    /// Human-readable label rendered in `DebugMenuView`.
    public var displayName: String {
        switch self {
        case .dealerDoesNotQualify:      return "Dealer fails to qualify"
        case .playerFlushOnRiver:        return "Player flush on river"
        case .push:                      return "Push (tie on a straight)"
        case .dealerNoQualifyPlayerPair: return "Dealer no-qualify vs player pair"
        }
    }

    /// The 9-card deal order consumed by `GameState.deal()`. Order is:
    /// `[playerHole1, playerHole2, dealerHole1, dealerHole2, flop1,
    /// flop2, flop3, turn, river]`. Each preset is hand-verified against
    /// the `HandEvaluator` so the engine produces the documented outcome
    /// regardless of player decision path.
    public var dealOrder: [Card] {
        switch self {
        case .dealerDoesNotQualify:
            // Player: K-Q offsuit-but-same-color → K-high after the board.
            // Dealer: 7-2 offsuit → J-high after the board (no pair).
            // Community: 4♣ 8♥ J♣ 9♦ 3♠ — all unique ranks, no help to
            // the dealer's hole cards → dealer hand-evaluates to .highCard
            // and `DealerQualification.qualifies` returns false.
            return [
                Card(rank: .king,  suit: .spades),
                Card(rank: .queen, suit: .spades),
                Card(rank: .seven, suit: .diamonds),
                Card(rank: .two,   suit: .hearts),
                Card(rank: .four,  suit: .clubs),
                Card(rank: .eight, suit: .hearts),
                Card(rank: .jack,  suit: .clubs),
                Card(rank: .nine,  suit: .diamonds),
                Card(rank: .three, suit: .spades),
            ]

        case .playerFlushOnRiver:
            // Player: A♥ K♥ (flush draw in hearts).
            // Dealer: Q♠ Q♦ (pair of queens — qualifies).
            // Community: 7♥ 2♠ 9♥ 3♣ J♥ — 4 hearts after the turn, the
            // 5th heart arrives on the river. Player makes an A-high
            // hearts flush on the river; dealer holds pair of queens.
            return [
                Card(rank: .ace,   suit: .hearts),
                Card(rank: .king,  suit: .hearts),
                Card(rank: .queen, suit: .spades),
                Card(rank: .queen, suit: .diamonds),
                Card(rank: .seven, suit: .hearts),
                Card(rank: .two,   suit: .spades),
                Card(rank: .nine,  suit: .hearts),
                Card(rank: .three, suit: .clubs),
                Card(rank: .jack,  suit: .hearts),
            ]

        case .dealerNoQualifyPlayerPair:
            // Player: 5♥ A♣ → pairs aces with the board ace.
            // Dealer: 5♣ J♦ → J-high after the board (each rank unique,
            // so no pair on either side except the player's ace pair).
            // Community: 3♥ 6♠ A♠ K♣ 2♥ — gives the player A-A and the
            // dealer K-J-6-5-3 high card. Dealer fails to qualify.
            // Reproduces the Session 32 on-device hand exactly.
            return [
                Card(rank: .five,  suit: .hearts),
                Card(rank: .ace,   suit: .clubs),
                Card(rank: .five,  suit: .clubs),
                Card(rank: .jack,  suit: .diamonds),
                Card(rank: .three, suit: .hearts),
                Card(rank: .six,   suit: .spades),
                Card(rank: .ace,   suit: .spades),
                Card(rank: .king,  suit: .clubs),
                Card(rank: .two,   suit: .hearts),
            ]

        case .push:
            // Player: 2♥ 3♥ (low hole cards, plays the board).
            // Dealer: 2♣ 3♣ (also low, also plays the board).
            // Community: A♠ K♠ Q♦ J♥ 10♥ — broadway straight on the
            // board. Both pools evaluate to the identical A-high
            // straight, so the main-bet outcome is push. A placed
            // Trips bet pays 5:1 for the straight regardless.
            return [
                Card(rank: .two,   suit: .hearts),
                Card(rank: .three, suit: .hearts),
                Card(rank: .two,   suit: .clubs),
                Card(rank: .three, suit: .clubs),
                Card(rank: .ace,   suit: .spades),
                Card(rank: .king,  suit: .spades),
                Card(rank: .queen, suit: .diamonds),
                Card(rank: .jack,  suit: .hearts),
                Card(rank: .ten,   suit: .hearts),
            ]
        }
    }
}

/// In-memory buffer holding a scenario armed by the DebugMenuView. The
/// `GameTableViewModel` reads (and clears) this on the next `deal()`,
/// so the force is single-shot and never persists across a force-quit.
///
/// Both touch points run on the main thread — the menu sheet sets it
/// from a SwiftUI gesture handler, and the view model reads it from
/// the DEAL button's tap path. The storage is `nonisolated(unsafe)`
/// rather than `@MainActor` because `GameTableViewModel` itself is not
/// main-actor isolated (it uses ad-hoc `Task { @MainActor in … }`), so
/// a strict isolation annotation here would force a refactor that
/// belongs in production code, not this DEBUG-only affordance.
public enum DebugDealForcer {
    nonisolated(unsafe) public static var pendingScenario: DebugScenario?
}

#endif
