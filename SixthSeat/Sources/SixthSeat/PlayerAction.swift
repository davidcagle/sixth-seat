import Foundation

/// Every input the player can submit to a `GameState`.
/// `GameState.perform(_:)` validates that an action is legal for the
/// current phase and returns a `GameError` otherwise.
public enum PlayerAction: Equatable, Sendable {
    /// Sets the Ante (and automatically the Blind, which always equals it).
    case placeAnte(amount: Int)

    /// Optional side bet placed before the deal.
    case placeTrips(amount: Int)

    /// Locks the wagers, deals two hole cards to the player and to the
    /// dealer, and advances to `.preFlopDecision`.
    case deal

    /// Places the Play wager pre-flop. Multiplier must be 3 or 4.
    case betPreFlop(multiplier: Int)

    /// Declines to bet pre-flop; the flop is dealt and the player faces
    /// the post-flop decision.
    case checkPreFlop

    /// Places the Play wager post-flop (always 2× Ante).
    case betPostFlop

    /// Declines to bet post-flop; the turn and river are dealt and the
    /// player faces the post-river decision.
    case checkPostFlop

    /// Places the Play wager post-river (always 1× Ante).
    case betPostRiver

    /// Forfeits the Ante and Blind. Only legal at `.postRiverDecision`
    /// (after both prior check decisions).
    case fold

    /// Pays out the resolved hand, clears state, and starts a new hand.
    case collectAndReset
}
