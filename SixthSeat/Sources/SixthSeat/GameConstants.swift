import Foundation

/// Cross-cutting numeric constants shared by the engine and the app.
///
/// These are values the rest of the codebase derives gates and
/// affordability checks from, rather than hard-coding numbers in
/// multiple places. The minimum chip value drives the smallest legal
/// wager step; the playable balance threshold derives from it.
public enum GameConstants {

    /// Smallest chip denomination on the V1 table. The Ante cycle's
    /// non-zero floor and the Trips cycle's first non-zero step both
    /// land here. (Future table-aware cycle ranges in Session 15 will
    /// vary this per table; the engine reads from this constant so the
    /// shape stays consistent.)
    public static let minimumChipValue = 5

    /// The smallest chip balance at which a player can place the
    /// minimum mandatory wagers (Ante + Blind). Below this, the player
    /// is functionally bust — no Ante step is affordable, so no hand
    /// can start. Used by the bust modal trigger and the menu-boundary
    /// fallback. (Session 12d)
    public static let minimumPlayableBalance = minimumChipValue * 2
}
