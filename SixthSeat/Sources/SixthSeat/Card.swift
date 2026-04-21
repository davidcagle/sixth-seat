import Foundation

public enum Suit: String, CaseIterable, Sendable {
    case clubs, diamonds, hearts, spades

    public var symbol: String {
        switch self {
        case .clubs:    return "\u{2663}"
        case .diamonds: return "\u{2666}"
        case .hearts:   return "\u{2665}"
        case .spades:   return "\u{2660}"
        }
    }
}

public enum Rank: Int, CaseIterable, Comparable, Sendable {
    // Raw values match poker value. Ace is HIGH (14).
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    public var display: String {
        switch self {
        case .two:   return "2"
        case .three: return "3"
        case .four:  return "4"
        case .five:  return "5"
        case .six:   return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine:  return "9"
        case .ten:   return "10"
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        case .ace:   return "A"
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Card: Equatable, Hashable, Comparable, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// Short display string, e.g. "A♠", "K♥", "10♦".
    public var display: String {
        "\(rank.display)\(suit.symbol)"
    }

    // Comparable by rank only; suit has no poker ordering in UTH.
    public static func < (lhs: Card, rhs: Card) -> Bool {
        lhs.rank < rhs.rank
    }
}
