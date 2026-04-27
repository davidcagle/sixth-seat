import Foundation
import Testing
@testable import SixthSeat

@Suite("InMemoryChipStore")
struct InMemoryChipStoreTests {

    @Test("Default values are 0 balance, false bonus flags, 0 hands played")
    func defaultValues() {
        let store = InMemoryChipStore()
        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedStarterBonus == false)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(store.totalHandsPlayed == 0)
    }

    @Test("Values can be set and retrieved")
    func setAndGetValues() {
        let store = InMemoryChipStore()
        store.chipBalance = 1_234
        store.hasReceivedStarterBonus = true
        store.hasReceivedSecondChanceBonus = true
        store.totalHandsPlayed = 42

        #expect(store.chipBalance == 1_234)
        #expect(store.hasReceivedStarterBonus == true)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(store.totalHandsPlayed == 42)
    }

    @Test("reset() clears every value back to its default")
    func resetClearsValues() {
        let store = InMemoryChipStore(
            chipBalance: 9_000,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true,
            totalHandsPlayed: 7
        )

        store.reset()

        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedStarterBonus == false)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(store.totalHandsPlayed == 0)
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

    @Test("Does not trigger when balance is above zero")
    func skipsWhenPlayerStillHasChips() {
        let store = InMemoryChipStore(chipBalance: 1)
        let applied = BonusLogic.applySecondChanceBonusIfEligible(store: store)

        #expect(applied == false)
        #expect(store.chipBalance == 1)
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
}
