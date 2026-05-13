import Foundation

/// Chip-stack visualization for a bet amount.
///
/// The V1 chip set is `$5 / $25 / $100 / $500 / $1,000`. `bestFit`
/// picks the largest denomination that divides `amount` cleanly so
/// the rendered stack is an exact representation, not a single-chip
/// approximation: `$50 → (25, 2)`, not `(25, 1)`. Bets that don't
/// land on a multiple of `$5` (which today the engine never produces)
/// fall back to `nil` — the dollar-label adjacent to the bet zone
/// still communicates the exact value.
///
/// Lives in the engine package because the math is pure integer
/// arithmetic that's worth asserting directly, same pattern as
/// `StackHeight.bestFit(for:)` (Session 17).
public struct ChipDecomposition: Equatable, Sendable {
    public let denomination: Int
    public let count: Int

    public init(denomination: Int, count: Int) {
        self.denomination = denomination
        self.count = count
    }

    /// Available chip denominations, largest first.
    public static let availableDenominations: [Int] = [1000, 500, 100, 25, 5]

    /// Picks the largest denomination D where `amount % D == 0` and
    /// returns `(D, amount / D)`. Returns `nil` for `amount <= 0` or
    /// when no available denomination divides `amount` cleanly (e.g.
    /// `$1`, which the engine should never produce).
    public static func bestFit(for amount: Int) -> ChipDecomposition? {
        guard amount > 0 else { return nil }
        for denom in availableDenominations where denom <= amount && amount % denom == 0 {
            return ChipDecomposition(denomination: denom, count: amount / denom)
        }
        return nil
    }
}
