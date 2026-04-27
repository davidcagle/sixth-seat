import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("MainMenuView")
struct MainMenuViewTests {

    // MARK: - Play button enabled state

    @Test("Play enabled when balance is well above the minimum")
    func playEnabledAboveMinimum() {
        #expect(MainMenuLogic.playEnabled(balance: 1_000, hasUsedSecondChance: false))
        #expect(MainMenuLogic.playEnabled(balance: 1_000, hasUsedSecondChance: true))
    }

    @Test("Play enabled at exactly the table minimum")
    func playEnabledAtMinimum() {
        #expect(MainMenuLogic.playEnabled(balance: MainMenuLogic.tableMinimumStake, hasUsedSecondChance: false))
        #expect(MainMenuLogic.playEnabled(balance: MainMenuLogic.tableMinimumStake, hasUsedSecondChance: true))
    }

    @Test("Play disabled with sub-minimum non-zero balance")
    func playDisabledSubMinimum() {
        #expect(!MainMenuLogic.playEnabled(balance: 1, hasUsedSecondChance: false))
        #expect(!MainMenuLogic.playEnabled(balance: 4, hasUsedSecondChance: true))
    }

    @Test("Play enabled when busted but second-chance bonus is still available")
    func playEnabledWhenBustedWithRescue() {
        #expect(MainMenuLogic.playEnabled(balance: 0, hasUsedSecondChance: false))
    }

    @Test("Play disabled when busted and second-chance bonus already used")
    func playDisabledWhenBustedNoRescue() {
        #expect(!MainMenuLogic.playEnabled(balance: 0, hasUsedSecondChance: true))
    }

    // MARK: - Busted hint visibility

    @Test("Busted hint hidden when balance is positive")
    func bustedHintHiddenAboveZero() {
        #expect(!MainMenuLogic.showsBustedHint(balance: 100, hasUsedSecondChance: false))
        #expect(!MainMenuLogic.showsBustedHint(balance: 100, hasUsedSecondChance: true))
    }

    @Test("Busted hint hidden when busted but rescue still available")
    func bustedHintHiddenWithRescue() {
        #expect(!MainMenuLogic.showsBustedHint(balance: 0, hasUsedSecondChance: false))
    }

    @Test("Busted hint shown when busted with no rescue left")
    func bustedHintShownNoRescue() {
        #expect(MainMenuLogic.showsBustedHint(balance: 0, hasUsedSecondChance: true))
    }

    // MARK: - Play tap & second-chance bonus wiring

    @Test("Play tap on busted store grants second-chance bonus and allows navigation")
    func playTapGrantsSecondChance() {
        let store = InMemoryChipStore(
            chipBalance: 0,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == BonusLogic.secondChanceBonusAmount)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(shouldNavigate == true)
    }

    @Test("Play tap with healthy balance leaves bonus state untouched")
    func playTapWithHealthyBalanceUnchanged() {
        let store = InMemoryChipStore(
            chipBalance: 1_000,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == 1_000)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(shouldNavigate == true)
    }

    @Test("Play tap on busted-with-rescue-spent store does NOT re-grant and blocks navigation")
    func playTapBustedNoRescueBlocks() {
        let store = InMemoryChipStore(
            chipBalance: 0,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(shouldNavigate == false)
    }

    // MARK: - Balance formatting

    @Test("Balance formats as USD currency without fractional digits")
    func balanceFormatting() {
        #expect(MainMenuLogic.formatBalance(5_000) == "$5,000")
        #expect(MainMenuLogic.formatBalance(0) == "$0")
        #expect(MainMenuLogic.formatBalance(1_234_567) == "$1,234,567")
    }

    // MARK: - View instantiation (compile-time + smoke)

    @Test("MainMenuView and stubs instantiate with their dependencies")
    func viewsInstantiate() {
        let store = InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true)
        var path: [MenuDestination] = []
        let binding = Binding<[MenuDestination]>(get: { path }, set: { path = $0 })
        _ = MainMenuView(chipStore: store, path: binding)
        _ = SettingsView()
        _ = ChipShopView()
        _ = HowToPlayView()
    }

    // MARK: - Bankroll-survives-the-loop integration

    @Test("Shared store carries balance changes from a played hand back to the menu")
    func bankrollSurvivesGameRoundTrip() {
        // One store, used by a "menu" snapshot before the game and
        // by the game VM. After the VM mutates balance via wagers,
        // re-reading the same store reflects the new balance — this
        // is the proof that menu↔game share state through ChipStore.
        let store = InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true)
        let menuBalanceBefore = store.chipBalance

        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.placeAnte(amount: 25) // debits 50 (ante + blind)

        let menuBalanceAfter = store.chipBalance

        #expect(menuBalanceBefore == 5_000)
        #expect(menuBalanceAfter == 4_950)
        #expect(menuBalanceAfter < menuBalanceBefore)
    }
}
