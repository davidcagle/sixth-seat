import Foundation
import SixthSeat

/// Top-level stage the table is animating through. Mirrors the user-visible
/// motion sequence: cards flip, then bet zones resolve.
public enum AnimationStage: Equatable, Sendable {
    case idle
    case dealingPlayer
    case revealingFlop
    case revealingTurn
    case revealingRiver
    case revealingFlopTurnRiver
    case revealingDealer
    case resolvingChips
    case settled
}

/// Per-bet-zone resolution motion. Drives the BetZoneView animations.
public enum BetZoneAnimation: Equatable, Sendable {
    case none
    case pulsing      // win/push opening pulse before slide
    case slidingDown  // push or win — toward player tray
    case slidingUp    // loss — toward dealer
    case faded        // off-screen / fully transparent
    case winMatched   // win: doubled stack visible just before sliding down
}

/// Identifies one of the four bet zones the player can have in play.
public enum BetZoneIdentifier: Sendable {
    case ante, blind, play, trips
}

/// What happens to a single bet zone at hand resolution. Computed from a
/// `HandResult` plus the zone's stake.
public enum BetZoneOutcome: Equatable, Sendable {
    case push
    case loss
    case win
    case noBet  // zone had no stake — nothing to animate
}

public extension BetZoneOutcome {

    /// Maps an engine `BetOutcome` + stake into a coarse motion outcome.
    /// `.blindBonus` is treated as `.win` for the chip animation — the
    /// payout multiplier affects balance, not motion shape (Tier 1).
    static func from(outcome: BetOutcome, stake: Int) -> BetZoneOutcome {
        guard stake > 0 else { return .noBet }
        switch outcome {
        case .win, .blindBonus: return .win
        case .lose:             return .loss
        case .push:             return .push
        }
    }
}

/// Abstraction over the wall-clock waits the animation state machine uses.
/// Real builds use `RealAnimationClock` (`Task.sleep`); tests use a mock
/// that fires waits synchronously so behavior is verifiable without flaky
/// real-time delays.
public protocol AnimationClock: Sendable {
    func sleep(milliseconds: Int) async
}

public struct RealAnimationClock: AnimationClock {
    public init() {}
    public func sleep(milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

/// Test clock that resolves all sleeps immediately. Lets us drive the
/// state machine through every stage in a single test run with no waits.
public struct ImmediateAnimationClock: AnimationClock {
    public init() {}
    public func sleep(milliseconds: Int) async { /* no-op */ }
}
