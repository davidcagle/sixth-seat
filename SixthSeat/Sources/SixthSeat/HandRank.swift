import Foundation

/// Poker hand categories, ordered weakest-to-strongest.
/// Raw value is the category's base score: highCard = 1 ... royalFlush = 10.
public enum HandRank: Int, Comparable, Equatable, Sendable, CaseIterable {
    case highCard      = 1
    case pair          = 2
    case twoPair       = 3
    case threeOfAKind  = 4
    case straight      = 5
    case flush         = 6
    case fullHouse     = 7
    case fourOfAKind   = 8
    case straightFlush = 9
    case royalFlush    = 10

    public static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
