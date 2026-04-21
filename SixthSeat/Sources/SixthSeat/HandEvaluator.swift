import Foundation

/// Classifies a set of 5, 6, or 7 cards into the best 5-card poker hand.
public enum HandEvaluator {

    /// Returns the best 5-card `EvaluatedHand` from the given cards.
    /// Accepts exactly 5, 6, or 7 cards. Ties are broken by `tiebreakers`.
    public static func evaluate(cards: [Card]) -> EvaluatedHand {
        precondition(
            (5...7).contains(cards.count),
            "HandEvaluator requires 5, 6, or 7 cards; got \(cards.count)"
        )

        if cards.count == 5 {
            return evaluateFive(cards)
        }

        var best: EvaluatedHand?
        for combo in combinations(of: cards, choose: 5) {
            let candidate = evaluateFive(combo)
            if best == nil || candidate > best! {
                best = candidate
            }
        }
        return best!
    }

    // MARK: - 5-card evaluation

    private static func evaluateFive(_ cards: [Card]) -> EvaluatedHand {
        precondition(cards.count == 5)

        // Rank values, with cards sorted high-to-low.
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let values = sorted.map { $0.rank.rawValue }

        let isFlush = Set(sorted.map { $0.suit }).count == 1

        // WHEEL STRAIGHT: A-2-3-4-5 is the one case where the ace (rawValue 14)
        // is treated as LOW (value 1). Any other straight is simply 5
        // consecutive ranks, so we detect the wheel by its exact signature.
        let isWheel = values == [14, 5, 4, 3, 2]
        let isNormalStraight: Bool = {
            guard Set(values).count == 5 else { return false }
            return values.first! - values.last! == 4
        }()
        let isStraight = isWheel || isNormalStraight
        let straightHigh = isWheel ? 5 : values.first!

        // For a wheel, present cards in 5-4-3-2-A order (ace last = low).
        let orderedForStraight: [Card] = {
            if isWheel {
                let ace = sorted.first!
                return Array(sorted.dropFirst()) + [ace]
            }
            return sorted
        }()

        // Rank-count groups, sorted by (count desc, rank desc).
        var counts: [Int: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        let groups = counts
            .map { (rank: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.rank > rhs.rank
            }

        // Straight flush / royal flush
        if isStraight && isFlush {
            if straightHigh == 14 {
                return EvaluatedHand(
                    rank: .royalFlush,
                    cards: orderedForStraight,
                    tiebreakers: [14]
                )
            }
            return EvaluatedHand(
                rank: .straightFlush,
                cards: orderedForStraight,
                tiebreakers: [straightHigh]
            )
        }

        // Four of a kind
        if groups[0].count == 4 {
            let quad = groups[0].rank
            let kicker = groups[1].rank
            let ordered = sorted.filter { $0.rank.rawValue == quad } +
                          sorted.filter { $0.rank.rawValue == kicker }
            return EvaluatedHand(
                rank: .fourOfAKind,
                cards: ordered,
                tiebreakers: [quad, kicker]
            )
        }

        // Full house
        if groups[0].count == 3 && groups[1].count == 2 {
            let trip = groups[0].rank
            let pair = groups[1].rank
            let ordered = sorted.filter { $0.rank.rawValue == trip } +
                          sorted.filter { $0.rank.rawValue == pair }
            return EvaluatedHand(
                rank: .fullHouse,
                cards: ordered,
                tiebreakers: [trip, pair]
            )
        }

        // Flush (non-straight)
        if isFlush {
            return EvaluatedHand(
                rank: .flush,
                cards: sorted,
                tiebreakers: values
            )
        }

        // Straight (non-flush)
        if isStraight {
            return EvaluatedHand(
                rank: .straight,
                cards: orderedForStraight,
                tiebreakers: [straightHigh]
            )
        }

        // Three of a kind
        if groups[0].count == 3 {
            let trip = groups[0].rank
            let kickers = groups.dropFirst().map { $0.rank }
            let ordered = sorted.filter { $0.rank.rawValue == trip } +
                          sorted.filter { $0.rank.rawValue != trip }
            return EvaluatedHand(
                rank: .threeOfAKind,
                cards: ordered,
                tiebreakers: [trip] + kickers
            )
        }

        // Two pair
        if groups[0].count == 2 && groups[1].count == 2 {
            let highPair = groups[0].rank
            let lowPair = groups[1].rank
            let kicker = groups[2].rank
            let ordered = sorted.filter { $0.rank.rawValue == highPair } +
                          sorted.filter { $0.rank.rawValue == lowPair } +
                          sorted.filter { $0.rank.rawValue == kicker }
            return EvaluatedHand(
                rank: .twoPair,
                cards: ordered,
                tiebreakers: [highPair, lowPair, kicker]
            )
        }

        // One pair
        if groups[0].count == 2 {
            let pair = groups[0].rank
            let kickers = groups.dropFirst().map { $0.rank }
            let ordered = sorted.filter { $0.rank.rawValue == pair } +
                          sorted.filter { $0.rank.rawValue != pair }
            return EvaluatedHand(
                rank: .pair,
                cards: ordered,
                tiebreakers: [pair] + kickers
            )
        }

        // High card
        return EvaluatedHand(
            rank: .highCard,
            cards: sorted,
            tiebreakers: values
        )
    }

    // MARK: - Combinations

    /// All k-sized combinations of `items`, preserving input order within each combination.
    private static func combinations<T>(of items: [T], choose k: Int) -> [[T]] {
        precondition(k >= 0 && k <= items.count)
        if k == 0 { return [[]] }
        if k == items.count { return [items] }

        var result: [[T]] = []
        var indices = Array(0..<k)
        let n = items.count

        while true {
            result.append(indices.map { items[$0] })
            var i = k - 1
            while i >= 0 && indices[i] == i + n - k {
                i -= 1
            }
            if i < 0 { break }
            indices[i] += 1
            for j in (i + 1)..<k {
                indices[j] = indices[j - 1] + 1
            }
        }
        return result
    }
}
