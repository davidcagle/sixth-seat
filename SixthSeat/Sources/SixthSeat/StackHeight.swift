import Foundation

/// Available chip-stack art heights. The Phase 1 designer ships five
/// stack variants per denomination — 1, 3, 5, 10, and 20 chips tall —
/// so a runtime chip count must round down to the largest variant that
/// fits.
///
/// Lives in the engine package because `bestFit(for:)` is pure
/// integer arithmetic with no SwiftUI dependency. The app layer
/// consumes this through `AssetService.chipStackImage(denomination:height:)`.
public enum StackHeight: Int, CaseIterable, Sendable {
    case h1 = 1
    case h3 = 3
    case h5 = 5
    case h10 = 10
    case h20 = 20

    /// Largest available variant ≤ `chipCount`. A count below 1 is
    /// clamped to `.h1` (callers should not be rendering stacks for
    /// zero-chip wagers, but the floor keeps the function total).
    public static func bestFit(for chipCount: Int) -> StackHeight {
        let n = max(1, chipCount)
        // Walk descending — first variant ≤ n wins.
        for variant in [StackHeight.h20, .h10, .h5, .h3, .h1] where variant.rawValue <= n {
            return variant
        }
        return .h1
    }
}
