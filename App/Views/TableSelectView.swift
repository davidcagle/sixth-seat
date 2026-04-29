import SwiftUI
import SixthSeat

/// Pure helpers backing `TableSelectView`'s decision logic. Extracted
/// so the affordability gate, the "fall back to Chip Shop" safety net,
/// and the persisted-id round-trip are unit-testable without
/// instantiating the SwiftUI view hierarchy.
enum TableSelectLogic {

    /// Whether the player's balance can afford a single DEAL at this
    /// table's minimum Ante (worst-case main bet = 6 × Ante). Mirrors
    /// the Session 12d in-game gate so the picker never lets a player
    /// enter a table they can't act in. (Session 15b)
    static func canEnter(_ table: TableConfig, balance: Int) -> Bool {
        balance >= table.minimumEntryBalance
    }

    /// True when no table in the registry is enterable from this
    /// balance. The view uses this to route to the Chip Shop as a
    /// safety net — the bust modal is the primary path for that case,
    /// but a fresh launch into an unaffordable state is possible.
    static func allTablesUnaffordable(balance: Int, tables: [TableConfig] = TableConfig.all) -> Bool {
        !tables.contains { canEnter($0, balance: balance) }
    }

    /// Resolves the persisted `selectedTableID` to a concrete config,
    /// falling back to `TableConfig.defaultTable` for nil or unknown
    /// values. Wraps `TableConfig.table(forID:)` so callers don't have
    /// to know about the engine helper.
    static func resolveLastPlayed(id: String?) -> TableConfig {
        TableConfig.table(forID: id)
    }
}

/// Lets the player pick their stake before entering the game. Three
/// cards rendered vertically; tapping a card persists the table id
/// and pushes `.game(tableID:)` onto the navigation stack. Cards are
/// disabled when the balance can't cover the table's minimum entry.
struct TableSelectView: View {

    let chipStore: ChipStoreProtocol
    @Binding var path: [MenuDestination]

    @AppStorage(PersistenceKeys.selectedTableID) private var lastPlayedID: String = TableConfig.defaultTable.id
    @State private var balance: Int = 0

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()

            VStack(spacing: 18) {
                header
                Spacer().frame(height: 4)
                ForEach(TableConfig.all) { table in
                    tableCard(table)
                }
                Spacer()
                if TableSelectLogic.allTablesUnaffordable(balance: balance) {
                    chipShopFallbackButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationTitle("Choose a Table")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
    }

    private func refresh() {
        balance = chipStore.chipBalance
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("CHOOSE A TABLE")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))
            Text(MainMenuLogic.formatBalance(balance))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .accessibilityIdentifier("TableSelect.Balance")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Table card

    @ViewBuilder
    private func tableCard(_ table: TableConfig) -> some View {
        let canEnter = TableSelectLogic.canEnter(table, balance: balance)
        let isLastPlayed = lastPlayedID == table.id

        Button {
            select(table)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(table.displayName)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(canEnter ? .white : .white.opacity(0.45))
                        if isLastPlayed {
                            Text("LAST PLAYED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(.black)
                                .background(Capsule().fill(Color.yellow))
                                .accessibilityIdentifier("TableSelect.LastPlayed.\(table.id)")
                        }
                    }
                    Text("Minimum bet: $\(table.minimumAnte)")
                        .font(.system(size: 13))
                        .foregroundStyle(canEnter ? .white.opacity(0.85) : .white.opacity(0.4))
                    Text(table.anteRangeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(canEnter ? .white.opacity(0.65) : .white.opacity(0.3))
                }
                Spacer()
                if !canEnter {
                    Text("Need $\(table.minimumEntryBalance)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.yellow.opacity(0.85))
                        .accessibilityIdentifier("TableSelect.NeedHint.\(table.id)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canEnter ? Color.black.opacity(0.35) : Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        canEnter ? Color.white.opacity(0.25) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canEnter)
        .accessibilityIdentifier("TableSelect.Card.\(table.id)")
    }

    private func select(_ table: TableConfig) {
        // Persist the choice BEFORE the navigation push so the next
        // mount of this screen reads the correct "Last played" id even
        // if the player force-quits between tap and game entry.
        lastPlayedID = table.id
        path.append(.game(tableID: table.id))
    }

    // MARK: - Fallback

    private var chipShopFallbackButton: some View {
        Button {
            // Replace the route stack so Back from Chip Shop returns to
            // the menu, not to this empty picker. Mirrors the second-bust
            // navigation pattern from Session 12b.
            path = [.chipShop]
        } label: {
            Text("Visit Chip Shop")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.black)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color.yellow)
                )
        }
        .accessibilityIdentifier("TableSelect.VisitChipShop")
    }
}

#Preview {
    NavigationStack {
        TableSelectView(
            chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true),
            path: .constant([.tableSelect])
        )
    }
}
