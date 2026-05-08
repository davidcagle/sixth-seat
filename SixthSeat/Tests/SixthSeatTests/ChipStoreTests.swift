import Foundation
import Testing
@testable import SixthSeat

@Suite("InMemoryChipStore")
struct InMemoryChipStoreTests {

    @Test("Default values are 0 balance, false bonus flags, 0 hands played, doubler armed, no processed transactions")
    func defaultValues() {
        let store = InMemoryChipStore()
        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedStarterBonus == false)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(store.totalHandsPlayed == 0)
        #expect(store.hasMadeFirstPurchase == false)
        #expect(store.processedTransactionIDs.isEmpty)
    }

    @Test("Values can be set and retrieved")
    func setAndGetValues() {
        let store = InMemoryChipStore()
        store.chipBalance = 1_234
        store.hasReceivedStarterBonus = true
        store.hasReceivedSecondChanceBonus = true
        store.totalHandsPlayed = 42
        store.hasMadeFirstPurchase = true
        store.processedTransactionIDs = ["tx-a", "tx-b"]

        #expect(store.chipBalance == 1_234)
        #expect(store.hasReceivedStarterBonus == true)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(store.totalHandsPlayed == 42)
        #expect(store.hasMadeFirstPurchase == true)
        #expect(store.processedTransactionIDs == ["tx-a", "tx-b"])
    }

    @Test("reset() clears every value — including IAP idempotency state — back to its default")
    func resetClearsValues() {
        let store = InMemoryChipStore(
            chipBalance: 9_000,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true,
            totalHandsPlayed: 7,
            hasMadeFirstPurchase: true,
            processedTransactionIDs: ["tx-1"]
        )

        store.reset()

        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedStarterBonus == false)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(store.totalHandsPlayed == 0)
        #expect(store.hasMadeFirstPurchase == false)
        #expect(store.processedTransactionIDs.isEmpty)
    }
}

@Suite("UserDefaultsChipStore")
struct UserDefaultsChipStoreTests {

    /// Builds a fresh, isolated `UserDefaults` so the test can exercise
    /// `UserDefaultsChipStore` without leaking into other tests or the
    /// real user's defaults database. Each test uses a unique suite
    /// name and removes it before constructing the store.
    private static func freshDefaults(
        suite: String = "com.sixthseat.test.\(UUID().uuidString)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Init applies the starter bonus eagerly so the menu shows 5,000 on fresh install")
    func initAppliesStarterBonus() {
        let defaults = Self.freshDefaults()
        let store = UserDefaultsChipStore(defaults: defaults)

        #expect(store.chipBalance == 5_000)
        #expect(store.hasReceivedStarterBonus == true)
        #expect(store.hasReceivedSecondChanceBonus == false)
    }

    @Test("Re-initializing with the same defaults does not stack the starter bonus")
    func reinitDoesNotStackStarter() {
        let defaults = Self.freshDefaults()
        _ = UserDefaultsChipStore(defaults: defaults) // first instance grants the bonus
        let second = UserDefaultsChipStore(defaults: defaults)

        // The flag from the first instance prevents a second grant.
        #expect(second.chipBalance == 5_000)
        #expect(second.hasReceivedStarterBonus == true)
    }

    @Test("Init does not apply the starter bonus when the flag is already set")
    func initRespectsPreExistingFlag() {
        let suite = "com.sixthseat.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        // Simulate a returning player: they have a non-default balance
        // and the flag is already set from a prior session.
        defaults.set(750, forKey: PersistenceKeys.chipBalance)
        defaults.set(true, forKey: PersistenceKeys.hasReceivedStarterBonus)

        let store = UserDefaultsChipStore(defaults: defaults)

        #expect(store.chipBalance == 750)
        #expect(store.hasReceivedStarterBonus == true)
    }

    @Test("hasMadeFirstPurchase round-trips through UserDefaults — fresh install reads false, then write+read true")
    func hasMadeFirstPurchaseRoundTrip() {
        let defaults = Self.freshDefaults()
        let store = UserDefaultsChipStore(defaults: defaults)

        #expect(store.hasMadeFirstPurchase == false)
        store.hasMadeFirstPurchase = true
        #expect(store.hasMadeFirstPurchase == true)
        // Reading via raw UserDefaults confirms the persisted shape.
        #expect(defaults.bool(forKey: PersistenceKeys.hasMadeFirstPurchase) == true)
    }

    @Test("processedTransactionIDs round-trips as a [String] in UserDefaults and re-reads as a Set")
    func processedTransactionIDsRoundTrip() {
        let defaults = Self.freshDefaults()
        let store = UserDefaultsChipStore(defaults: defaults)

        #expect(store.processedTransactionIDs.isEmpty)

        store.processedTransactionIDs = ["tx-z", "tx-a", "tx-m"]
        let stored = defaults.array(forKey: PersistenceKeys.processedTransactionIDs) as? [String]
        #expect(stored == ["tx-a", "tx-m", "tx-z"]) // sorted on write for stable storage shape
        #expect(store.processedTransactionIDs == ["tx-a", "tx-m", "tx-z"])
    }

    @Test("reset() clears the IAP idempotency keys alongside the chip-economy keys")
    func resetClearsIAPKeys() {
        let defaults = Self.freshDefaults()
        let store = UserDefaultsChipStore(defaults: defaults)
        store.hasMadeFirstPurchase = true
        store.processedTransactionIDs = ["tx-1", "tx-2"]
        store.chipBalance = 12_345

        store.reset()

        #expect(store.hasMadeFirstPurchase == false)
        #expect(store.processedTransactionIDs.isEmpty)
        #expect(store.chipBalance == 0)
        #expect(defaults.object(forKey: PersistenceKeys.hasMadeFirstPurchase) == nil)
        #expect(defaults.object(forKey: PersistenceKeys.processedTransactionIDs) == nil)
    }
}

@Suite("BonusLogic.starterBonus")
struct StarterBonusTests {

    @Test("First call adds 5000 chips and returns true")
    func firstCallGrantsBonus() {
        let store = InMemoryChipStore()
        let applied = BonusLogic.applyStarterBonusIfEligible(store: store)

        #expect(applied == true)
        #expect(store.chipBalance == 5_000)
        #expect(store.hasReceivedStarterBonus == true)
    }

    @Test("Second call does nothing and returns false")
    func secondCallIsNoOp() {
        let store = InMemoryChipStore()
        _ = BonusLogic.applyStarterBonusIfEligible(store: store)

        let applied = BonusLogic.applyStarterBonusIfEligible(store: store)

        #expect(applied == false)
        #expect(store.chipBalance == 5_000) // unchanged from first grant
        #expect(store.hasReceivedStarterBonus == true)
    }

    @Test("If flag is already set, no chips are added regardless of current balance")
    func respectsPreExistingFlag() {
        let store = InMemoryChipStore(chipBalance: 250, hasReceivedStarterBonus: true)
        let applied = BonusLogic.applyStarterBonusIfEligible(store: store)

        #expect(applied == false)
        #expect(store.chipBalance == 250)
    }
}

@Suite("BonusLogic.secondChanceBonus")
struct SecondChanceBonusTests {

    @Test("Grants 2500 chips when balance is 0 and bonus not yet received")
    func grantsBonusWhenBusted() {
        let store = InMemoryChipStore() // balance 0, flag false
        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == true)
        #expect(store.chipBalance == 2_500)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("Grants chips when balance is below the playable threshold (Session 12d)")
    func grantsBonusBelowPlayableThreshold() {
        // Balance 5 < minimumPlayableBalance (10) — the player can't
        // afford even the smallest Ante + Blind cycle, so the bonus
        // applies. Pre-Session 12d this would have skipped because
        // the gate was `balance == 0`.
        let store = InMemoryChipStore(chipBalance: 5)
        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == true)
        #expect(store.chipBalance == 2_505)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("Does not trigger when balance meets the playable threshold")
    func skipsWhenPlayerStillHasChips() {
        // Balance 10 is exactly `minimumPlayableBalance` — the player
        // can still afford Ante + Blind at the smallest cycle step,
        // so the bonus does not fire.
        let store = InMemoryChipStore(chipBalance: GameConstants.minimumPlayableBalance)
        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == false)
        #expect(store.chipBalance == GameConstants.minimumPlayableBalance)
        #expect(store.hasReceivedSecondChanceBonus == false)
    }

    @Test("Does not trigger a second time even if the player busts again")
    func onlyFiresOnce() {
        let store = InMemoryChipStore()
        _ = BonusLogic.applySecondChanceBonusIfEligible(store: store)
        // Player spends everything and busts again.
        store.chipBalance = 0

        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == false)
        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("Second-chance bonus fires when balance is stranded between zero and the cheapest table's minimum entry — Session 18b regression guard")
    func secondChanceBonusFiresWhenStrandedBetweenStakeMinimums() {
        // Session 18a phone-test pass surfaced this gap: at $30 the
        // player was above the old global threshold (Session 12d's $10)
        // but below every V1 table's `minimumEntryBalance` (cheapest is
        // $60 at .table10) — so no table was enterable AND the bust
        // trigger never fired. The threshold must track the cheapest
        // table's entry, not a fixed chip-floor multiple. If a future
        // session changes stake levels again, this test is the guard
        // that the threshold keeps pace.
        let store = InMemoryChipStore(chipBalance: 30)
        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == true)
        #expect(store.chipBalance == 30 + BonusLogic.secondChanceBonusAmount)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }
}

@Suite("GameConstants (Session 12d)")
struct GameConstantsTests {

    @Test("minimumChipValue is the V1 chip floor")
    func minimumChipValueIsFive() {
        #expect(GameConstants.minimumChipValue == 5)
    }

    @Test("minimumPlayableBalance equals the cheapest table's minimum entry — Session 18b table-aware threshold")
    func minimumPlayableBalanceTracksCheapestTableEntry() {
        // The threshold is "smallest balance at which *some* table is
        // still enterable" — i.e. the cheapest table's worst-case 6×
        // Ante main bet. Pre-Session 18b this was a fixed 2× chip
        // floor ($10), which silently stranded balances in the gap
        // between $10 and the cheapest entry once Session 15b raised
        // stake levels. The threshold must derive from `TableConfig`
        // so any future stake-level change carries the trigger with it.
        #expect(GameConstants.minimumPlayableBalance == TableConfig.cheapestEntryBalance)
        #expect(GameConstants.minimumPlayableBalance == 60)
    }
}
