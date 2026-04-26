import Foundation

/// How loud the hand-result celebration should be. Computed from the
/// player's or dealer's `HandRank`. Tier 1 hands resolve with the existing
/// chip motion only; Tier 2-4 trigger an extra ceremony beat before chips
/// move.
public enum CeremonyTier: Int, Comparable, Sendable {
    case standard = 1   // High card, pair, two pair — no ceremony
    case notable  = 2   // Three of a kind, straight
    case big      = 3   // Flush, full house, four of a kind
    case jackpot  = 4   // Straight flush, royal flush

    public static func < (lhs: CeremonyTier, rhs: CeremonyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension HandRank {
    /// Tier of celebration this rank earns at hand resolution.
    var ceremonyTier: CeremonyTier {
        switch self {
        case .highCard, .pair, .twoPair:        return .standard
        case .threeOfAKind, .straight:          return .notable
        case .flush, .fullHouse, .fourOfAKind:  return .big
        case .straightFlush, .royalFlush:       return .jackpot
        }
    }
}
