import Foundation

/// Per-bet resolution logic for Ultimate Texas Hold'em.
///
/// All functions are pure: they take fully evaluated 5-card hands and
/// return a `BetOutcome`. Stake amounts and net payouts live in
/// `BetResolution` so this file can stay focused on the rules themselves.
public enum UTHRules {

    // MARK: - Paytables

    /// Blind bonus multipliers. Only paid when the player WINS the hand
    /// AND has at least a straight; lower winning hands push the Blind.
    public static let blindPaytable: [HandRank: Double] = [
        .royalFlush:    500,
        .straightFlush:  50,
        .fourOfAKind:    10,
        .fullHouse:       3,
        .flush:           1.5,
        .straight:        1
    ]

    /// Trips side-bet multipliers. Independent of the dealer hand and of
    /// the main-bet outcome — pays purely on the player's own 5-card rank.
    public static let tripsPaytable: [HandRank: Double] = [
        .royalFlush:    50,
        .straightFlush: 40,
        .fourOfAKind:   30,
        .fullHouse:      8,
        .flush:          6,
        .straight:       5,
        .threeOfAKind:   3
    ]

    // MARK: - Per-bet resolution

    /// Ante: pushes if the dealer fails to qualify; otherwise resolves 1:1
    /// against the dealer's hand (push on tie).
    public static func resolveAnte(player: EvaluatedHand, dealer: EvaluatedHand) -> BetOutcome {
        guard DealerQualification.qualifies(hand: dealer) else { return .push }
        return headsUp(player: player, dealer: dealer)
    }

    /// Play: always resolves 1:1 against the dealer's hand. NOT gated by
    /// dealer qualification — that gate applies only to the Ante.
    public static func resolvePlay(player: EvaluatedHand, dealer: EvaluatedHand) -> BetOutcome {
        headsUp(player: player, dealer: dealer)
    }

    /// Blind: pays the Blind paytable when the player wins with a straight
    /// or better; pushes when the player wins with a weaker hand; pushes on
    /// tie; loses when the player loses.
    public static func resolveBlind(player: EvaluatedHand, dealer: EvaluatedHand) -> BetOutcome {
        if player < dealer { return .lose }
        if player == dealer { return .push }
        if let multiplier = blindPaytable[player.rank] {
            return .blindBonus(multiplier: multiplier)
        }
        return .push
    }

    /// Trips: pays the Trips paytable on three of a kind or better;
    /// loses otherwise. Independent of the dealer's hand entirely.
    public static func resolveTrips(player: EvaluatedHand) -> BetOutcome {
        if let multiplier = tripsPaytable[player.rank] {
            return .blindBonus(multiplier: multiplier)
        }
        return .lose
    }

    // MARK: - Helpers

    private static func headsUp(player: EvaluatedHand, dealer: EvaluatedHand) -> BetOutcome {
        if player > dealer { return .win }
        if player < dealer { return .lose }
        return .push
    }
}
