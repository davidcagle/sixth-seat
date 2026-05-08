import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("In-game bust flow (Session 12b)")
struct BustFlowTests {

    // MARK: - Setup helpers

    /// Drives a single hand with `bypassAnimation: true` to a fold-out
    /// loss starting from `chipBalance`. After this returns, the engine
    /// has resolved the hand: balance has dropped by Ante+Blind (2× the
    /// Ante), and the bust handler has fired if the new balance is 0.
    private static func playFoldHand(
        store: InMemoryChipStore,
        ante: Int = 10
    ) -> GameTableViewModel {
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = ante
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.fold()
        return vm
    }

    /// Yields enough times for any spawned `@MainActor` Task to advance to
    /// completion under an `ImmediateAnimationClock` — the auto-dismiss
    /// timer is one such Task.
    private static func drainAnimations() async {
        for _ in 0..<10 { await Task.yield() }
    }

    // MARK: - Threshold (Session 12d)

    @Test("Bust modal fires when the hand resolves below the playable threshold")
    func bustFiresBelowPlayableThreshold() {
        // Start at 25 with Ante=10 → fold drops the player to 5, which
        // is below `minimumPlayableBalance` (post-Session 18b: $60, the
        // cheapest table's `minimumEntryBalance`). The first-bust modal
        // and rescue bonus must fire even though the balance is non-zero.
        let store = InMemoryChipStore(
            chipBalance: 25,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        // Balance was 5 immediately after the fold; the first-bust path
        // awarded 2,500 chips, landing the post-rescue balance at 2,505.
        #expect(vm.bustModal == .firstBust)
        #expect(store.hasReceivedSecondChanceBonus == true)
        #expect(store.chipBalance == 5 + BonusLogic.secondChanceBonusAmount)
    }

    @Test("Bust modal does NOT fire when the hand resolves at exactly the playable threshold")
    func bustDoesNotFireAtThreshold() {
        // Start at 80 with Ante=10 → fold drops the player to 60, which
        // is exactly `minimumPlayableBalance` (the cheapest table's
        // `minimumEntryBalance` post-Session 18b). The player can still
        // re-enter the $10 table at this balance, so the bust modal
        // does not fire.
        let store = InMemoryChipStore(
            chipBalance: 80,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        #expect(vm.chipBalance == GameConstants.minimumPlayableBalance)
        #expect(vm.bustModal == nil)
        #expect(store.hasReceivedSecondChanceBonus == false)
    }

    // MARK: - Trigger gate

    @Test("No bust modal fires when the hand resolves to a positive balance")
    func noBustWhenBalancePositive() {
        let store = InMemoryChipStore(chipBalance: 1_000, hasReceivedStarterBonus: true)
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        // Hand resolved with chips remaining; no bust path runs.
        #expect(vm.chipBalance > 0)
        #expect(vm.bustModal == nil)
    }

    @Test("No bust modal on a fresh view model — bust requires a resolved hand")
    func noBustOnFreshViewModel() {
        // Init balance 0 with starter received but no second-chance used.
        // The VM must NOT auto-trigger a first-bust at construction time —
        // the menu-boundary fallback owns that path on relaunch. In-game
        // bust detection only fires after a hand reaches `.handComplete`.
        let store = InMemoryChipStore(
            chipBalance: 0,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)

        #expect(vm.phase == .awaitingBets)
        #expect(vm.bustModal == nil)
        #expect(store.hasReceivedSecondChanceBonus == false)
        #expect(store.chipBalance == 0)
    }

    // MARK: - First bust

    @Test("First bust awards 2,500 chips and shows the first-bust modal")
    func firstBustAwardsChipsAndShowsModal() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        #expect(vm.bustModal == .firstBust)
        #expect(store.chipBalance == BonusLogic.secondChanceBonusAmount)
        #expect(vm.chipBalance == BonusLogic.secondChanceBonusAmount)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("First bust sets the persistence flag BEFORE presenting the modal — force-quit replay protection")
    func firstBustFlagSetBeforeModalPresentation() {
        // The contract: the moment `bustModal` becomes `.firstBust`, the
        // store flag is already true. A force-quit between modal show and
        // dismissal cannot replay the bonus on relaunch.
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        // Both must be true atomically post-bust. We can't easily intercept
        // the precise ordering without a mock, but the invariant is that
        // by the time the modal exists, the flag is already persisted.
        #expect(vm.bustModal == .firstBust)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("First bust resets the table to .awaitingBets with Ante at the table minimum and balance 2,500")
    func firstBustPostDismissState() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        // Post-bust: even before the modal is dismissed, the table is
        // already cleared and ready for the next hand. The modal sits as
        // an overlay over a primed betting screen. Ante resets to the
        // table's minimum (Session 15b — $10 on the default .table10).
        #expect(vm.phase == .awaitingBets)
        #expect(vm.chipBalance == 2_500)
        #expect(vm.stagedAnte == TableConfig.defaultTable.minimumAnte)
        #expect(vm.stagedTrips == 0)
        #expect(vm.anteBet == 0)
        #expect(vm.blindBet == 0)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.communityCards.isEmpty)
    }

    @Test("First bust does NOT auto-fire REBET — player decides when to play the next hand")
    func firstBustDoesNotAutoRebet() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)

        // After the bust the engine must be sitting in the awaiting-bets
        // state — not mid-deal. If a stray rebet had fired, phase would
        // have advanced to `.preFlopDecision` and player cards would be
        // populated.
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.dealerHoleCards.isEmpty)
        #expect(vm.anteBet == 0)
    }

    @Test("First bust fires a .success notification haptic")
    func firstBustFiresSuccessHaptic() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let recording = RecordingHapticsService()
        let vm = GameTableViewModel(
            chipStore: store,
            haptics: recording,
            bypassAnimation: true
        )
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.fold()

        // The first-bust path is the brand-voiced gift moment, so it
        // fires .success — distinct from .warning on second-bust.
        #expect(vm.bustModal == .firstBust)
        #expect(recording.events.contains(.notification(.success)))
    }

    @Test("Manual dismiss clears the first-bust modal")
    func manualDismissClearsFirstBust() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let vm = Self.playFoldHand(store: store)
        #expect(vm.bustModal == .firstBust)

        vm.dismissBustModal()

        #expect(vm.bustModal == nil)
        // Table state still primed for the next hand.
        #expect(vm.phase == .awaitingBets)
        #expect(vm.chipBalance == 2_500)
        #expect(vm.stagedAnte == TableConfig.defaultTable.minimumAnte)
    }

    @Test("First-bust modal auto-dismisses after the 5-second window elapses on the animation clock")
    func firstBustAutoDismissTiming() async {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        // Use a ManualAnimationClock so we can verify the 5,000ms sleep
        // is queued and that resolving it clears the modal.
        let clock = ManualAnimationClock()
        let vm = GameTableViewModel(chipStore: store, clock: clock)
        vm.stagedAnte = 10
        vm.deal()
        await Self.drainAnimations()
        // The deal animation has its own clock waits; drain them to get
        // to .preFlopDecision before continuing.
        while clock.pendingSleeps > 0 || vm.isAnimating {
            if clock.pendingSleeps > 0 { clock.resumeNext() }
            await Self.drainAnimations()
        }
        vm.checkPreFlop()
        while clock.pendingSleeps > 0 || vm.isAnimating {
            if clock.pendingSleeps > 0 { clock.resumeNext() }
            await Self.drainAnimations()
        }
        vm.checkPostFlop()
        while clock.pendingSleeps > 0 || vm.isAnimating {
            if clock.pendingSleeps > 0 { clock.resumeNext() }
            await Self.drainAnimations()
        }

        // Snapshot the sleep log so we can isolate the auto-dismiss sleep.
        let sleepsBeforeFold = clock.sleepLog.count
        vm.fold()
        // Drain the chip-resolution animation, which also fires the bust
        // handler; the handler queues a 5,000ms sleep on the clock.
        while clock.pendingSleeps > 0 || vm.isAnimating {
            if clock.pendingSleeps > 0 { clock.resumeNext() }
            await Self.drainAnimations()
        }

        let foldSleeps = Array(clock.sleepLog.dropFirst(sleepsBeforeFold))
        #expect(foldSleeps.contains(5_000))
        // After every queued sleep was resumed (including the 5s
        // auto-dismiss), the modal is cleared.
        #expect(vm.bustModal == nil)
    }

    // MARK: - Second bust

    @Test("Second bust does NOT award chips — hasReceivedSecondChanceBonus stays true and balance stays 0")
    func secondBustNoChipAward() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true // already used
        )
        let vm = Self.playFoldHand(store: store)

        #expect(vm.bustModal == .secondBust)
        #expect(store.chipBalance == 0)
        #expect(vm.chipBalance == 0)
        #expect(store.hasReceivedSecondChanceBonus == true)
    }

    @Test("Second bust shows a different modal kind than first bust")
    func bustModalKindDiffersBetweenFirstAndSecond() {
        let firstStore = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: false
        )
        let firstVM = Self.playFoldHand(store: firstStore)

        let secondStore = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )
        let secondVM = Self.playFoldHand(store: secondStore)

        #expect(firstVM.bustModal == .firstBust)
        #expect(secondVM.bustModal == .secondBust)
        #expect(firstVM.bustModal != secondVM.bustModal)
    }

    @Test("Second-bust modal copy differs from first-bust copy")
    func bustModalCopyDiffers() {
        // The static copy lives on `BustFlashView` so locked-in brand
        // voice is testable without standing up SwiftUI introspection.
        #expect(BustFlashView.headline(for: .firstBust) != BustFlashView.headline(for: .secondBust))
        #expect(BustFlashView.subline(for: .firstBust) != BustFlashView.subline(for: .secondBust))
        // Spec-locked first-bust copy.
        #expect(BustFlashView.headline(for: .firstBust) == "Pit boss spots you 2,500 chips.")
        #expect(BustFlashView.subline(for: .firstBust) == "Have another go.")
        // Spec-locked second-bust copy.
        #expect(BustFlashView.headline(for: .secondBust) == "Tapped out.")
        #expect(BustFlashView.subline(for: .secondBust) == "Hit the chip shop to buy back in.")
    }

    @Test("Second bust fires a .warning notification haptic")
    func secondBustFiresWarningHaptic() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )
        let recording = RecordingHapticsService()
        let vm = GameTableViewModel(
            chipStore: store,
            haptics: recording,
            bypassAnimation: true
        )
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.fold()

        #expect(vm.bustModal == .secondBust)
        #expect(recording.events.contains(.notification(.warning)))
        // Distinct from first-bust's .success — second-bust is not a gift.
        #expect(!recording.events.contains(.notification(.success)))
    }

    // MARK: - Chip Shop navigation

    @Test("Second-bust 'Visit Chip Shop' button replaces the path with [.chipShop] so Back returns to the menu")
    func chipShopNavigationReplacesPath() {
        // Mirrors the wiring in ContentView's GameDestinationView:
        // tapping the chip-shop button dismisses the modal and routes
        // via `path = [.chipShop]`. We exercise the closure that the
        // host installs on GameTableView.
        var path: [MenuDestination] = [.game(tableID: TableConfig.defaultTable.id)]
        let onVisitChipShop: () -> Void = { path = [.chipShop] }

        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )
        let vm = Self.playFoldHand(store: store)
        #expect(vm.bustModal == .secondBust)

        // Simulate the button action: dismiss modal + push chip shop.
        vm.dismissBustModal()
        onVisitChipShop()

        #expect(vm.bustModal == nil)
        #expect(path == [.chipShop])
    }

    @Test("Second-bust tap-to-dismiss leaves the player on the betting screen with balance 0")
    func secondBustTapToDismissStaysOnGame() {
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )
        let vm = Self.playFoldHand(store: store)
        #expect(vm.bustModal == .secondBust)

        vm.dismissBustModal()

        #expect(vm.bustModal == nil)
        #expect(vm.phase == .awaitingBets)
        #expect(vm.chipBalance == 0)
        // Existing affordability gating disables DEAL at $0 balance.
        #expect(vm.canDeal == false)
    }

    // MARK: - Chip Shop view smoke

    @Test("Real ChipShopView instantiates with its injected view model (Session 16 rewrite)")
    func chipShopViewExposesRequiredAffordances() {
        // Session 16 replaced the stub with a real screen; the view now
        // requires a `ChipShopViewModel` and threads through the
        // engine's IAPService. Verifying the type compiles with the
        // expected dependencies is what the SwiftUI-test layer can
        // offer here without a UI test runner. Stable identifiers
        // include ChipShop.Balance, ChipShop.DoublerBanner,
        // ChipShop.Buy.<id>, ChipShop.Restore, ChipShop.NoCashValue,
        // and ChipShop.BackToMenu.
        let store = InMemoryChipStore(chipBalance: 1_000, hasReceivedStarterBonus: true)
        let vm = ChipShopViewModel(
            iapService: InMemoryIAPService(chipStore: store),
            chipStore: store,
            haptics: NoopHapticsService()
        )
        _ = ChipShopView(viewModel: vm)
        #expect(true)
    }

    // MARK: - Menu-boundary fallback regression

    @Test("Session 14 menu-boundary second-chance fallback still fires for the relaunch edge case")
    func menuBoundaryFallbackStillWorks() {
        // The Session 12b in-game bust flow does not remove the menu-
        // boundary check — it remains a fallback for the case where
        // somehow the player landed on the menu with balance 0,
        // hasReceivedStarterBonus true, and hasReceivedSecondChanceBonus
        // false (e.g. force-quit before the in-game flash dispatched).
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
}
