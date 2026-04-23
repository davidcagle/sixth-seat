import Foundation

/// The phases of a single hand of Ultimate Texas Hold'em.
///
/// A hand always starts at `.awaitingBets` and ends at `.handComplete`.
/// `.postFlopDecision` is only reachable when the player checked pre-flop;
/// `.postRiverDecision` is only reachable when the player checked both
/// pre-flop and post-flop. Once a play bet is placed at any decision point,
/// the next phase is `.resolving`.
public enum GamePhase: Equatable, Sendable {
    case awaitingBets
    case preFlopDecision
    case postFlopDecision
    case postRiverDecision
    case resolving
    case handComplete
}
