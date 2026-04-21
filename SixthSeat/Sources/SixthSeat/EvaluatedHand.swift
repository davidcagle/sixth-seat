import Foundation

/// A ranked 5-card poker hand.
///
/// `tiebreakers` is an ordered list (highest-significance first) of integer
/// rank values used to compare two hands within the same `HandRank`. Two
/// hands are equal in value iff their `rank` and `tiebreakers` are equal —
/// suit composition does not affect poker value.
public struct EvaluatedHand: Comparable, Equatable, Sendable {
    public let rank: HandRank
    public let cards: [Card]
    public let tiebreakers: [Int]

    public init(rank: HandRank, cards: [Card], tiebreakers: [Int]) {
        self.rank = rank
        self.cards = cards
        self.tiebreakers = tiebreakers
    }

    public static func == (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        lhs.rank == rhs.rank && lhs.tiebreakers == rhs.tiebreakers
    }

    public static func < (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        for (l, r) in zip(lhs.tiebreakers, rhs.tiebreakers) {
            if l != r { return l < r }
        }
        return lhs.tiebreakers.count < rhs.tiebreakers.count
    }
}
