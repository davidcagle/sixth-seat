import Foundation

/// Single source of truth for a table's bet cycle ranges and minimum
/// stake. The app reads `anteCycle` and `tripsCycle` off a `TableConfig`
/// instance instead of hard-coding cycles in the view model. The engine
/// itself does not gate on table identity — `TableConfig` exists so the
/// UI can pick a stake range and so the cycle data has one home.
///
/// Cycle conventions (mirrored across all three tables):
/// * `anteCycle` ends with `0` — the cleared / unstaged position.
/// * `tripsCycle` starts with `0` — the "off" position.
/// * `minimumAnte` is the first non-zero entry in `anteCycle`.
public struct TableConfig: Equatable, Hashable, Codable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let minimumAnte: Int
    public let anteCycle: [Int]
    public let tripsCycle: [Int]

    public init(
        id: String,
        displayName: String,
        minimumAnte: Int,
        anteCycle: [Int],
        tripsCycle: [Int]
    ) {
        self.id = id
        self.displayName = displayName
        self.minimumAnte = minimumAnte
        self.anteCycle = anteCycle
        self.tripsCycle = tripsCycle
    }
}

public extension TableConfig {

    /// Smallest non-zero step in `tripsCycle`. Used by the Trips zone's
    /// affordability gate to decide whether the zone can be tapped at
    /// all from the current Ante and balance.
    var minimumTripsStep: Int {
        tripsCycle.first(where: { $0 > 0 }) ?? 0
    }

    static let table10 = TableConfig(
        id: "table_10",
        displayName: "$10 Table",
        minimumAnte: 10,
        anteCycle: [10, 15, 25, 50, 100, 0],
        tripsCycle: [0, 5, 10, 25]
    )

    static let table25 = TableConfig(
        id: "table_25",
        displayName: "$25 Table",
        minimumAnte: 25,
        anteCycle: [25, 50, 100, 250, 500, 0],
        tripsCycle: [0, 5, 10, 25, 50]
    )

    static let table50 = TableConfig(
        id: "table_50",
        displayName: "$50 Table",
        minimumAnte: 50,
        anteCycle: [50, 100, 200, 500, 1000, 0],
        tripsCycle: [0, 10, 25, 50, 100]
    )

    /// V1 ships three table stakes; ordered low-to-high so the table
    /// picker renders in the natural progression.
    static let all: [TableConfig] = [.table10, .table25, .table50]

    /// Default landing table on first launch and after a reset of the
    /// last-played-table preference. The lowest stake keeps the new-
    /// player path forgiving.
    static let defaultTable: TableConfig = .table10

    /// Lookup by id — used to restore the last-played table from the
    /// persisted `selectedTableID` preference. Returns the default
    /// table when the id no longer matches a known config.
    static func table(forID id: String?) -> TableConfig {
        guard let id else { return defaultTable }
        return all.first(where: { $0.id == id }) ?? defaultTable
    }

    /// Smallest balance that affords at least one DEAL at this table's
    /// minimum Ante (worst-case main bet = 6 × Ante). Below this the
    /// table picker should disable the card. (Mirrors the in-game
    /// affordability gate from Session 12d.)
    var minimumEntryBalance: Int {
        minimumAnte * 6
    }

    /// Smallest `minimumEntryBalance` across every V1 table — i.e. the
    /// chip floor at which *some* table is still enterable. Below this
    /// the player is functionally bust regardless of which table they
    /// might pick. Drives the in-game bust trigger and the menu-
    /// boundary second-chance fallback so neither can drift behind a
    /// stake-level change. (Session 18b — closes the stranded-balance
    /// gap introduced in Session 15b when stake levels expanded.)
    static var cheapestEntryBalance: Int {
        all.map(\.minimumEntryBalance).min() ?? 0
    }

    /// Bet range the table picker shows on each card —
    /// "$10 – $100" form, smallest non-zero Ante step to largest.
    /// Routes through a thousands-separating formatter so the $50 card
    /// renders "$50 – $1,000", not "$50 – $1000". (Session 18b — was
    /// raw integer interpolation, drifted from the 2026-05-04 currency
    /// convention.)
    var anteRangeDescription: String {
        let nonZero = anteCycle.filter { $0 > 0 }
        guard let lo = nonZero.min(), let hi = nonZero.max() else { return "" }
        return "$\(ChipShopLogic.formatChipAmount(lo)) – $\(ChipShopLogic.formatChipAmount(hi))"
    }
}
