import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("GameTableViewModel")
struct GameTableViewModelTests {

    @Test("Fresh view model applies starter bonus to empty store")
    func freshViewModelGrantsStarterBonus() {
        let store = InMemoryChipStore()
        let vm = GameTableViewModel(chipStore: store)

        #expect(vm.chipBalance == BonusLogic.starterBonusAmount)
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("placeAnte updates the view model's anteBet and blindBet")
    func placeAnteUpdatesWagers() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        vm.placeAnte(amount: 25)

        #expect(vm.anteBet == 25)
        #expect(vm.blindBet == 25)
        #expect(vm.chipBalance == 1_000 - 50)
        #expect(vm.errorMessage == nil)
    }

    @Test("deal() populates hole cards and advances phase")
    func dealPopulatesHoleCards() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
        vm.stagedAnte = 10

        vm.deal()

        #expect(vm.phase == .preFlopDecision)
        #expect(vm.playerHoleCards.count == 2)
        #expect(vm.dealerHoleCards.count == 2)
        #expect(vm.anteBet == 10)
    }

    @Test("Illegal action sets errorMessage and leaves state untouched")
    func illegalActionSetsError() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        // betPreFlop is illegal at .awaitingBets.
        vm.betPreFlop(multiplier: 3)

        #expect(vm.errorMessage != nil)
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
    }

    @Test("Insufficient-chips failure surfaces in errorMessage")
    func insufficientChipsSurfacesError() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5))

        // Blind auto-matches Ante, so an ante of 10 needs 20 chips.
        vm.placeAnte(amount: 10)

        #expect(vm.errorMessage?.contains("20") == true)
        #expect(vm.anteBet == 0)
    }

    @Test("Full hand resolution updates lastHandResult and balance")
    func fullHandResolutionUpdatesResult() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
        vm.stagedAnte = 10

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.phase == .handComplete)
        #expect(vm.lastHandResult != nil)
        #expect(vm.communityCards.count == 5)
        #expect(vm.chipBalance >= 0)
    }

    @Test("newHand resets to awaitingBets with cleared state")
    func newHandResetsState() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
        vm.stagedAnte = 10

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()
        vm.newHand()

        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.communityCards.isEmpty)
        #expect(vm.anteBet == 0)
        #expect(vm.lastHandResult == nil)
    }

    @Test("Staged ante cycles through steps via increment/decrement")
    func stagedAnteIncrementDecrement() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000))
        vm.stagedAnte = 10

        vm.incrementStagedAnte()
        #expect(vm.stagedAnte == 25)
        vm.incrementStagedAnte()
        #expect(vm.stagedAnte == 50)
        vm.decrementStagedAnte()
        #expect(vm.stagedAnte == 25)
    }

    @Test("formattedBalance uses currency formatting")
    func formattedBalanceUsesCommas() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5_000))

        let formatted = vm.formattedBalance
        #expect(formatted.contains("5,000"))
    }

    /// Most tests want to exercise the view model without the one-time
    /// starter bonus inflating their balances, so we hand the view model
    /// a store that already records the bonus as claimed.
    private static func bonusClaimed(chipBalance: Int) -> InMemoryChipStore {
        InMemoryChipStore(chipBalance: chipBalance, hasReceivedStarterBonus: true)
    }
}
