import Foundation

/// All failure modes that `GameState.perform(_:)` can return.
public enum GameError: Error, Equatable, Sendable {
    /// The action is not legal for the current phase.
    case illegalActionForPhase(attempted: PlayerAction, phase: GamePhase)

    /// The wager would exceed the player's chip balance.
    case insufficientChips(required: Int, available: Int)

    /// The bet amount is otherwise invalid (e.g. zero or negative,
    /// or attempted before required prerequisites).
    case invalidBetAmount(reason: String)

    /// The pre-flop multiplier is not one of the allowed values.
    case invalidMultiplier(given: Int, allowed: [Int])
}
