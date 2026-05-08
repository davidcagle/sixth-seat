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

    /// The smallest chip balance at which the player can DEAL at *some*
    /// table — i.e. the cheapest table's `minimumEntryBalance`. Below
    /// this, no V1 table is enterable and the player is functionally
    /// bust. Drives the in-game bust trigger and the menu-boundary
    /// second-chance fallback. Single source of truth so the trigger
    /// cannot drift when stake levels change. (Session 18b — was a
    /// fixed `2 × minimumChipValue` per Session 12d, which silently
    /// stranded balances in the gap between $10 and the cheapest table
    /// entry once Session 15b introduced higher-stake tables.)
    public static var minimumPlayableBalance: Int {
        TableConfig.cheapestEntryBalance
    }
}
