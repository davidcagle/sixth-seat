import Foundation

/// The resolution of a single bet.
/// - `win`/`lose`/`push` describe 1:1 or even-money outcomes.
/// - `blindBonus` carries a paytable multiplier so the same case can express
///   both the Blind bonus ladder (e.g. 500:1 royal) and the Trips side-bet
///   ladder (e.g. 3:1 three of a kind). A pushed Blind is `.push`, not a
///   zero-multiplier bonus.
public enum BetOutcome: Equatable, Sendable {
    case win
    case lose
    case push
    case blindBonus(multiplier: Double)
}

/// The complete resolution of one UTH hand: both hands, whether the dealer
/// qualified, and the outcome + net chip change for each of the four bets
/// the player may have had in play.
///
/// `net` amounts are from the player's perspective: positive = profit,
/// negative = loss, zero = push. Push returns the original wager without
/// a net change (the stake itself is assumed to be tracked elsewhere).
public struct HandResult: Equatable, Sendable {
    public let playerHand: EvaluatedHand
    public let dealerHand: EvaluatedHand
    public let dealerQualifies: Bool

    public let anteOutcome: BetOutcome
    public let blindOutcome: BetOutcome
    public let playOutcome: BetOutcome
    public let tripsOutcome: BetOutcome

    public let anteNet: Double
    public let blindNet: Double
    public let playNet: Double
    public let tripsNet: Double

    public var totalNet: Double {
        anteNet + blindNet + playNet + tripsNet
    }

    public init(
        playerHand: EvaluatedHand,
        dealerHand: EvaluatedHand,
        dealerQualifies: Bool,
        anteOutcome: BetOutcome,
        blindOutcome: BetOutcome,
        playOutcome: BetOutcome,
        tripsOutcome: BetOutcome,
        anteNet: Double,
        blindNet: Double,
        playNet: Double,
        tripsNet: Double
    ) {
        self.playerHand = playerHand
        self.dealerHand = dealerHand
        self.dealerQualifies = dealerQualifies
        self.anteOutcome = anteOutcome
        self.blindOutcome = blindOutcome
        self.playOutcome = playOutcome
        self.tripsOutcome = tripsOutcome
        self.anteNet = anteNet
        self.blindNet = blindNet
        self.playNet = playNet
        self.tripsNet = tripsNet
    }
}

public enum BetResolution {

    /// Resolves every bet on a UTH hand and returns the combined result.
    /// Bet amounts of `0` are valid (the player did not place that wager);
    /// the outcome is still computed, but every net amount is `0`.
    public static func resolve(
        playerHand: EvaluatedHand,
        dealerHand: EvaluatedHand,
        anteBet: Double,
        blindBet: Double,
        playBet: Double,
        tripsBet: Double
    ) -> HandResult {
        let dealerQualifies = DealerQualification.qualifies(hand: dealerHand)

        let ante  = UTHRules.resolveAnte(player: playerHand, dealer: dealerHand)
        let play  = UTHRules.resolvePlay(player: playerHand, dealer: dealerHand)
        let blind = UTHRules.resolveBlind(player: playerHand, dealer: dealerHand)
        let trips = UTHRules.resolveTrips(player: playerHand)

        return HandResult(
            playerHand: playerHand,
            dealerHand: dealerHand,
            dealerQualifies: dealerQualifies,
            anteOutcome: ante,
            blindOutcome: blind,
            playOutcome: play,
            tripsOutcome: trips,
            anteNet:  netAmount(outcome: ante,  bet: anteBet),
            blindNet: netAmount(outcome: blind, bet: blindBet),
            playNet:  netAmount(outcome: play,  bet: playBet),
            tripsNet: netAmount(outcome: trips, bet: tripsBet)
        )
    }

    /// Translates a `BetOutcome` + stake into the player's net chip change.
    public static func netAmount(outcome: BetOutcome, bet: Double) -> Double {
        switch outcome {
        case .win:                          return  bet
        case .lose:                         return -bet
        case .push:                         return  0
        case .blindBonus(let multiplier):   return  bet * multiplier
        }
    }
}
