import Foundation

/// Single-stack chip-visualization decomposition for a bet amount.
///
/// The V1 chip set is `$5 / $25 / $100 / $500 / $1,000`. For bet
/// amounts that don't land cleanly on a single denomination (e.g.
/// `$35`) the bet zone falls back to a single-stack approximation —
/// the precise amount is communicated by the adjacent dollar label.
/// See Session 21 prompt: "START SIMPLE — render a single chip of
/// the largest denomination ≤ the bet amount."
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

    /// Picks a single-stack visualization for `amount`.
    ///
    /// Returns `nil` when no chips should render (`amount <= 0`).
    /// Otherwise picks the largest available denomination ≤ amount
    /// and sets `count = amount / denomination` (integer division —
    /// the dollar-label text on the bet zone provides the precise
    /// value when the result is a visual approximation).
    public static func bestFit(for amount: Int) -> ChipDecomposition? {
        guard amount > 0 else { return nil }
        for denom in availableDenominations where denom <= amount {
            return ChipDecomposition(denomination: denom, count: amount / denom)
        }
        return nil
    }
}
