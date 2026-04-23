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
