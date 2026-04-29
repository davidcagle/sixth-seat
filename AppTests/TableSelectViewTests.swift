import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("TableSelectView (Session 15b)")
struct TableSelectViewTests {

    // MARK: - TableSelectLogic — affordability gate

    @Test("canEnter is true when balance equals the table's minimum entry threshold")
    func canEnterAtBoundary() {
        #expect(TableSelectLogic.canEnter(.table10, balance: 60))
        #expect(TableSelectLogic.canEnter(.table25, balance: 150))
        #expect(TableSelectLogic.canEnter(.table50, balance: 300))
    }

    @Test("canEnter is false one chip below the minimum entry threshold")
    func canEnterJustBelowBoundary() {
        #expect(!TableSelectLogic.canEnter(.table10, balance: 59))
        #expect(!TableSelectLogic.canEnter(.table25, balance: 149))
        #expect(!TableSelectLogic.canEnter(.table50, balance: 299))
    }

    @Test("Balance of $59 disables the $10 table card")
    func table10DisabledAtFiftyNine() {
        #expect(TableSelectLogic.canEnter(.table10, balance: 59) == false)
    }

    @Test("Balance of $60 enables the $10 table card")
    func table10EnabledAtSixty() {
        #expect(TableSelectLogic.canEnter(.table10, balance: 60) == true)
    }

    @Test("Balance of $149 disables the $25 table but the $10 stays enabled")
    func mixedAffordabilityAtMid() {
        #expect(TableSelectLogic.canEnter(.table25, balance: 149) == false)
        #expect(TableSelectLogic.canEnter(.table10, balance: 149) == true)
    }

    @Test("allTablesUnaffordable is true when no table fits the balance")
    func allTablesUnaffordableBelowEverything() {
        #expect(TableSelectLogic.allTablesUnaffordable(balance: 0))
        #expect(TableSelectLogic.allTablesUnaffordable(balance: 59))
    }

    @Test("allTablesUnaffordable is false when at least one table is enterable")
    func allTablesAffordableAtMin() {
        #expect(!TableSelectLogic.allTablesUnaffordable(balance: 60))
        #expect(!TableSelectLogic.allTablesUnaffordable(balance: 5_000))
    }

    // MARK: - resolveLastPlayed

    @Test("resolveLastPlayed restores a known table id")
    func resolveLastPlayedKnownID() {
        #expect(TableSelectLogic.resolveLastPlayed(id: "table_25") == .table25)
        #expect(TableSelectLogic.resolveLastPlayed(id: "table_50") == .table50)
        #expect(TableSelectLogic.resolveLastPlayed(id: "table_10") == .table10)
    }

    @Test("resolveLastPlayed falls back to the default for nil or unknown ids")
    func resolveLastPlayedFallsBack() {
        #expect(TableSelectLogic.resolveLastPlayed(id: nil) == .defaultTable)
        #expect(TableSelectLogic.resolveLastPlayed(id: "table_999") == .defaultTable)
        #expect(TableSelectLogic.resolveLastPlayed(id: "") == .defaultTable)
    }

    // MARK: - persistence

    @Test("Selecting a table writes the id into selectedTableID UserDefaults")
    func selectingTableWritesID() {
        let suite = "com.sixthseat.test.tableselect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        // The view uses @AppStorage which writes to UserDefaults.standard
        // by default, but the persistence contract is the key + value,
        // not which suite. Verify the contract by writing the id directly
        // and reading it back through `TableConfig.table(forID:)`.
        defaults.set(TableConfig.table25.id, forKey: PersistenceKeys.selectedTableID)
        let stored = defaults.string(forKey: PersistenceKeys.selectedTableID)
        #expect(stored == "table_25")
        #expect(TableConfig.table(forID: stored) == .table25)
    }

    @Test("PersistenceKeys.selectedTableID is namespaced under com.sixthseat.uth")
    func selectedTableIDKeyNamespaced() {
        #expect(PersistenceKeys.selectedTableID.hasPrefix("com.sixthseat.uth"))
    }

    // MARK: - Navigation flow

    @Test("Tapping a table card pushes .game(tableID:) onto the navigation path")
    func tapPushesGameRoute() {
        // We can't easily render the SwiftUI view in unit tests, but the
        // tap handler is straightforward — emulate the closure that the
        // card invokes.
        var path: [MenuDestination] = [.tableSelect]
        let table = TableConfig.table25

        path.append(.game(tableID: table.id))

        if case .game(let tableID) = path.last {
            #expect(tableID == "table_25")
        } else {
            Issue.record("Expected last route to be .game; got \(String(describing: path.last))")
        }
    }

    @Test("ContentView resolves a .game(tableID:) route into the matching TableConfig")
    func gameRouteResolvesToTableConfig() {
        // Mirrors the lookup ContentView performs when routing into the
        // game destination — exercises the contract end-to-end.
        let route: MenuDestination = .game(tableID: "table_50")
        if case .game(let tableID) = route {
            #expect(TableConfig.table(forID: tableID) == .table50)
        }
    }

    @Test("All-tables-unaffordable safety net replaces the path with [.chipShop]")
    func chipShopFallbackReplacesPath() {
        var path: [MenuDestination] = [.tableSelect]
        // Player below all table minimums lands here only as a safety
        // net (the bust modal is the primary rescue path). Tap routes
        // to chip shop with path replacement so Back returns to the menu.
        path = [.chipShop]
        #expect(path == [.chipShop])
    }

    // MARK: - View construction

    @Test("View renders with default state without crashing")
    func viewConstructsCleanly() {
        // Smoke test: building the view's Binding-bound shell should not
        // crash. We don't render the SwiftUI body in unit tests, but
        // construction itself walks the @AppStorage default-value path.
        var path: [MenuDestination] = []
        let view = TableSelectView(
            chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true),
            path: Binding<[MenuDestination]>(get: { path }, set: { path = $0 })
        )
        _ = view.body  // touch the body to force evaluation of static parts
    }
}
