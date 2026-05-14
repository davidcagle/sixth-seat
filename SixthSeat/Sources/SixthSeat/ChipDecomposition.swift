import Foundation

/// One contiguous run of chips of a single denomination inside a bet-zone
/// chip stack. `ChipDecomposition.decompose(amount:)` returns an ordered
/// array of these (largest denomination first), which the view layer
/// renders as offset-stacked single-chip art.
public struct ChipChunk: Equatable, Sendable {
    public let denomination: Int
    public let count: Int

    public init(denomination: Int, count: Int) {
        self.denomination = denomination
        self.count = count
    }
}

/// Bet-zone chip-stack decomposition.
///
/// The V1 chip set is `$5 / $25 / $100 / $500 / $1,000`. `decompose`
/// runs a greedy largest-first pass over those denominations, returning
/// chunks ordered from largest to smallest. The view layer renders each
/// chunk as N copies of the single-chip art, offset-stacked, so a
/// `$125` bet becomes one `$100` chip on the bottom with one `$25`
/// chip stacked on top — matching the casino-felt convention of mixed
/// chips physically stacked.
///
/// Supersedes the Session 21/22 `bestFit(for:)` contract, which returned
/// a single denomination/count pair and could not express mixed-chip
/// bets (`$125 → ($25, 5)` instead of `[($100, 1), ($25, 1)]`).
///
/// Lives in the engine package because the math is pure integer
/// arithmetic that's worth asserting directly, same pattern as
/// `StackHeight.bestFit(for:)` (Session 17).
public enum ChipDecomposition {

    /// Available chip denominations, largest first. Matches the V1 chip
    /// set and the order the greedy decomposition walks.
    public static let availableDenominations: [Int] = [1000, 500, 100, 25, 5]

    /// Greedy largest-denomination-first decomposition of `amount` into
    /// chunks of the available denominations. Returns chunks ordered
    /// from largest denomination to smallest. Returns an empty array
    /// for `amount <= 0`. All V1 chip cycles produce amounts that
    /// decompose cleanly into the `$5/$25/$100/$500/$1000` set.
    public static func decompose(amount: Int) -> [ChipChunk] {
        guard amount > 0 else { return [] }
        var remaining = amount
        var chunks: [ChipChunk] = []
        for denom in availableDenominations {
            let count = remaining / denom
            if count > 0 {
                chunks.append(ChipChunk(denomination: denom, count: count))
                remaining -= denom * count
            }
        }
        return chunks
    }
}
