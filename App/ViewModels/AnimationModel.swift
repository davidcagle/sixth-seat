import Foundation
import SixthSeat

/// Top-level stage the table is animating through. Mirrors the user-visible
/// motion sequence: cards flip, then (for Tier 2-4 hands) a ceremony beat
/// plays, then bet zones resolve.
public enum AnimationStage: Equatable, Sendable {
    case idle
    case dealingPlayer
    case revealingFlop
    case revealingTurn
    case revealingRiver
    case revealingFlopTurnRiver
    case revealingDealer
    case ceremony           // Tier 2 (notable) or Tier 3 (big) celebration
    case jackpotCeremony    // Tier 4 — full-screen, tap-to-advance window
    case resolvingChips
    case settled
}

/// Snapshot of the data driving a hand-result ceremony. Built at the start
/// of resolution from the engine's `HandResult`. Decision authority for
/// when to show what UI lives on the view (player/dealer hand visibility
/// keys off `playerTier` / `dealerTier`).
public struct CeremonyState: Equatable, Sendable {
    public let playerHand: HandRank
    public let dealerHand: HandRank
    public let playerTier: CeremonyTier
    public let dealerTier: CeremonyTier
    public let isPlayerWin: Bool
    public let isDealerWin: Bool
    public let isPush: Bool
    /// Signed total chip change for the player across all four bets,
    /// rounded to whole chips. Folds Trips into the headline number when
    /// the ceremony also covers a Trips payout (decision 4).
    public let payoutAmount: Int

    public init(
        playerHand: HandRank,
        dealerHand: HandRank,
        playerTier: CeremonyTier,
        dealerTier: CeremonyTier,
        isPlayerWin: Bool,
        isDealerWin: Bool,
        isPush: Bool,
        payoutAmount: Int
    ) {
        self.playerHand = playerHand
        self.dealerHand = dealerHand
        self.playerTier = playerTier
        self.dealerTier = dealerTier
        self.isPlayerWin = isPlayerWin
        self.isDealerWin = isDealerWin
        self.isPush = isPush
        self.payoutAmount = payoutAmount
    }

    /// The tier that drives ceremony duration and layout. When both hands
    /// qualify (decision 3), the larger tier wins.
    public var effectiveTier: CeremonyTier {
        max(playerTier, dealerTier)
    }

    public var showsPlayerHand: Bool { playerTier >= .notable }
    public var showsDealerHand: Bool { dealerTier >= .notable }

    /// Whether the dealer's hand is the one being celebrated (drives muted
    /// styling per decision 2).
    public var isDealerCeremony: Bool {
        dealerTier > playerTier
    }

    /// Whether the gold treatment should apply. Reserved for player wins
    /// (decision 2). Dealer wins and pushes use neutral/muted palette.
    public var useGoldTreatment: Bool {
        isPlayerWin
    }

    /// Builds a ceremony from a resolved `HandResult`. Returns nil when
    /// neither hand reaches Tier 2 — Tier 1 hands resolve via existing
    /// chip motion only, with no ceremony beat.
    ///
    /// `payoutAmount` carries the signed total net (Ante + Play + Blind
    /// + Trips), which folds Trips into the headline payout per
    /// decision 4.
    public static func from(result: HandResult) -> CeremonyState? {
        let playerTier = result.playerHand.rank.ceremonyTier
        let dealerTier = result.dealerHand.rank.ceremonyTier
        guard max(playerTier, dealerTier) >= .notable else { return nil }

        let isPush: Bool
        let isPlayerWin: Bool
        let isDealerWin: Bool
        if result.playerHand == result.dealerHand {
            isPush = true; isPlayerWin = false; isDealerWin = false
        } else if result.playerHand > result.dealerHand {
            isPush = false; isPlayerWin = true;  isDealerWin = false
        } else {
            isPush = false; isPlayerWin = false; isDealerWin = true
        }

        return CeremonyState(
            playerHand: result.playerHand.rank,
            dealerHand: result.dealerHand.rank,
            playerTier: playerTier,
            dealerTier: dealerTier,
            isPlayerWin: isPlayerWin,
            isDealerWin: isDealerWin,
            isPush: isPush,
            payoutAmount: Int(result.totalNet.rounded())
        )
    }
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

/// Which in-game bust flash is on screen.
/// - `.firstBust`: the second-chance gift modal (auto-dismisses).
/// - `.secondBust`: the routing modal that points to the Chip Shop.
public enum BustModalKind: Equatable, Sendable {
    case firstBust
    case secondBust
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

/// Test clock that suspends every sleep call until `resumeNext` is invoked.
/// Lets tests inspect view-model state at exact beats in the choreography
/// (e.g. mid-ceremony lock-in) instead of after the run has completed.
///
/// The clock is only used by the test target — keep production paths on
/// `RealAnimationClock` or `ImmediateAnimationClock`.
public final class ManualAnimationClock: AnimationClock, @unchecked Sendable {
    private var pending: [CheckedContinuation<Void, Never>] = []
    public private(set) var sleepLog: [Int] = []

    public init() {}

    public func sleep(milliseconds: Int) async {
        await withCheckedContinuation { cont in
            sleepLog.append(milliseconds)
            pending.append(cont)
        }
    }

    /// Resumes the oldest currently-suspended sleep, if any.
    public func resumeNext() {
        guard !pending.isEmpty else { return }
        let cont = pending.removeFirst()
        cont.resume()
    }

    public var pendingSleeps: Int { pending.count }
}
