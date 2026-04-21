import Foundation
import Security

public struct Deck {
    public private(set) var cards: [Card]

    public init() {
        self.cards = Self.freshCards()
        shuffle()
    }

    public var count: Int { cards.count }

    /// Fisher-Yates shuffle using SecRandomCopyBytes as the entropy source.
    public mutating func shuffle() {
        var i = cards.count - 1
        while i > 0 {
            let j = Self.secureRandom(upperBound: UInt32(i + 1))
            cards.swapAt(i, Int(j))
            i -= 1
        }
    }

    /// Removes and returns the top card, or nil if the deck is empty.
    public mutating func deal() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeLast()
    }

    /// Restores the full 52-card deck and reshuffles it.
    public mutating func reset() {
        cards = Self.freshCards()
        shuffle()
    }

    private static func freshCards() -> [Card] {
        var result: [Card] = []
        result.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                result.append(Card(rank: rank, suit: suit))
            }
        }
        return result
    }

    /// Uniform, unbiased integer in `[0, upperBound)` from a cryptographically
    /// secure source. Uses rejection sampling to eliminate modulo bias.
    private static func secureRandom(upperBound: UInt32) -> UInt32 {
        precondition(upperBound > 0)
        let limit = UInt32.max - (UInt32.max % upperBound)
        while true {
            var value: UInt32 = 0
            let status = withUnsafeMutableBytes(of: &value) { buffer in
                SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
            }
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
            if value < limit {
                return value % upperBound
            }
        }
    }
}
