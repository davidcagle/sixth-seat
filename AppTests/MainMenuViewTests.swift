import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("MainMenuView")
struct MainMenuViewTests {

    // MARK: - Play button enabled state

    @Test("Play enabled when balance is well above the playable threshold")
    func playEnabledAboveMinimum() {
        #expect(MainMenuLogic.playEnabled(balance: 1_000, hasUsedSecondChance: false))
        #expect(MainMenuLogic.playEnabled(balance: 1_000, hasUsedSecondChance: true))
    }

    @Test("Play enabled at exactly the playable threshold")
    func playEnabledAtMinimum() {
        // At minimumPlayableBalance the player can afford Ante + Blind
        // at the smallest cycle step — playable in both flag states.
        // (Pre-Session 12d this used `tableMinimumStake = 5`; the new
        // threshold is `minimumPlayableBalance = 10`.)
        #expect(MainMenuLogic.playEnabled(balance: MainMenuLogic.minimumPlayableBalance, hasUsedSecondChance: false))
        #expect(MainMenuLogic.playEnabled(balance: MainMenuLogic.minimumPlayableBalance, hasUsedSecondChance: true))
    }

    @Test("Play disabled below threshold once the rescue has been used")
    func playDisabledSubMinimum() {
        #expect(!MainMenuLogic.playEnabled(balance: 1, hasUsedSecondChance: true))
        #expect(!MainMenuLogic.playEnabled(balance: 4, hasUsedSecondChance: true))
        #expect(!MainMenuLogic.playEnabled(balance: 5, hasUsedSecondChance: true))
        #expect(!MainMenuLogic.playEnabled(balance: 9, hasUsedSecondChance: true))
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

    @Test("Busted hint hidden when balance is positive and above threshold")
    func bustedHintHiddenAboveZero() {
        #expect(!MainMenuLogic.showsBustedHint(balance: 100, hasUsedSecondChance: false))
        #expect(!MainMenuLogic.showsBustedHint(balance: 100, hasUsedSecondChance: true))
    }

    @Test("Busted hint hidden when busted but rescue still available")
    func bustedHintHiddenWithRescue() {
        #expect(!MainMenuLogic.showsBustedHint(balance: 0, hasUsedSecondChance: false))
        #expect(!MainMenuLogic.showsBustedHint(balance: 5, hasUsedSecondChance: false))
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

    @Test("Play tap on a fresh-install store (starter not yet received) does NOT fire second-chance — prevents the 7,500 stacking bug")
    func playTapDoesNotStackBeforeStarter() {
        // The shape that produced the 7,500-chip stacking bug pre-Session 14a:
        // chip balance is 0 because the starter bonus has not yet fired,
        // so the old `balance == 0 && !secondChance` gate would happily
        // grant the second-chance bonus alongside the starter. The fix
        // requires `hasReceivedStarterBonus == true` before second-chance
        // can apply.
        let store = InMemoryChipStore(
            chipBalance: 0,
            hasReceivedStarterBonus: false,
            hasReceivedSecondChanceBonus: false
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == 0)
        #expect(store.hasReceivedSecondChanceBonus == false)
        // Without starter received and without chips, navigation is
        // still permitted because `playEnabled(balance: 0, hasUsed: false)`
        // returns true — but in production this case never reaches
        // the menu (UserDefaultsChipStore.init applies starter eagerly).
        #expect(shouldNavigate == true)
    }

    @Test("Play tap with starter received and balance just hit zero DOES grant second-chance (the post-bust path)")
    func playTapGrantsSecondChanceAfterBust() {
        let store = InMemoryChipStore(
            chipBalance: 0,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )

        _ = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == BonusLogic.secondChanceBonusAmount)
        #expect(store.hasReceivedSecondChanceBonus == true)
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

    // MARK: - Session 12d menu-boundary fallback

    @Test("Play tap with sub-threshold non-zero balance fires the first-bust rescue (Session 12d)")
    func playTapBelowThresholdFiresFirstBust() {
        // The post-bust menu fallback now extends beyond exact-zero:
        // a balance of $5 with the starter received and no rescue used
        // yet is functionally bust and should award the second-chance
        // bonus on Play tap, just like a balance of $0 would.
        let store = InMemoryChipStore(
            chipBalance: 5,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        // 5 + 2,500 = 2,505 — bonus stacks onto whatever the player had.
        #expect(store.chipBalance == 5 + BonusLogic.secondChanceBonusAmount)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(shouldNavigate == true)
    }

    @Test("Play tap with sub-threshold balance and rescue spent blocks navigation (Session 12d)")
    func playTapBelowThresholdAfterRescueBlocks() {
        // Second-bust routing at the menu: balance below the playable
        // threshold with the rescue already used means Play is blocked.
        // The view layer surfaces the busted hint and routes the player
        // to the Chip Shop.
        let store = InMemoryChipStore(
            chipBalance: 5,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )

        let shouldNavigate = MainMenuLogic.handlePlayTap(store: store)

        #expect(store.chipBalance == 5) // unchanged
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(shouldNavigate == false)
        #expect(MainMenuLogic.showsBustedHint(balance: store.chipBalance, hasUsedSecondChance: true))
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
        _ = ChipShopView(viewModel: ChipShopViewModel(
            iapService: InMemoryIAPService(chipStore: store),
            chipStore: store,
            haptics: NoopHapticsService()
        ))
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
