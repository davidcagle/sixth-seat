import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("GameTableViewModel")
struct GameTableViewModelTests {

    @Test("Fresh view model trusts the store balance and does not apply the starter bonus")
    func freshViewModelDoesNotGrantStarterBonus() {
        // Starter-bonus responsibility moved to `UserDefaultsChipStore.init`
        // in Session 14a so the Main Menu reflects the bonus immediately
        // (and so it can't stack with the second-chance bonus on Play-tap).
        // The VM now trusts whatever balance the store hands it.
        let store = InMemoryChipStore()
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)

        #expect(vm.chipBalance == 0)
        #expect(store.hasReceivedStarterBonus == false)
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("placeAnte updates the view model's anteBet and blindBet")
    func placeAnteUpdatesWagers() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.placeAnte(amount: 25)

        #expect(vm.anteBet == 25)
        #expect(vm.blindBet == 25)
        #expect(vm.chipBalance == 1_000 - 50)
        #expect(vm.errorMessage == nil)
    }

    @Test("deal() populates hole cards and advances phase")
    func dealPopulatesHoleCards() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10

        vm.deal()

        #expect(vm.phase == .preFlopDecision)
        #expect(vm.playerHoleCards.count == 2)
        #expect(vm.dealerHoleCards.count == 2)
        #expect(vm.anteBet == 10)
    }

    @Test("Illegal action sets errorMessage and leaves state untouched")
    func illegalActionSetsError() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        // betPreFlop is illegal at .awaitingBets.
        vm.betPreFlop(multiplier: 3)

        #expect(vm.errorMessage != nil)
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
    }

    @Test("Insufficient-chips failure surfaces in errorMessage")
    func insufficientChipsSurfacesError() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5), bypassAnimation: true)

        // Blind auto-matches Ante, so an ante of 10 needs 20 chips.
        vm.placeAnte(amount: 10)

        #expect(vm.errorMessage?.contains("20") == true)
        #expect(vm.anteBet == 0)
    }

    @Test("Full hand resolution updates lastHandResult and balance")
    func fullHandResolutionUpdatesResult() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
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
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
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
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
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
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5_000), bypassAnimation: true)

        let formatted = vm.formattedBalance
        #expect(formatted.contains("5,000"))
    }

    // MARK: - Trips side bet cycling

    @Test("Cycling Trips from off places $5")
    func cycleTripsFromOffPlacesFive() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.cycleTripsBet()

        #expect(vm.stagedTrips == 5)
        #expect(vm.displayedTripsBet == 5)
    }

    @Test("Cycling Trips from $5 advances to $10")
    func cycleTripsAdvancesToTen() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10

        #expect(vm.stagedTrips == 10)
    }

    @Test("Cycling Trips from $10 advances to $25")
    func cycleTripsAdvancesToTwentyFive() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10
        vm.cycleTripsBet() // 25

        #expect(vm.stagedTrips == 25)
    }

    @Test("Cycling Trips from $25 clears back to off")
    func cycleTripsWrapsToOff() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10
        vm.cycleTripsBet() // 25
        vm.cycleTripsBet() // off

        #expect(vm.stagedTrips == 0)
        #expect(vm.displayedTripsBet == 0)
    }

    @Test("Cycling Trips does not affect Ante or Blind")
    func cycleTripsIndependentOfAnteAndBlind() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.placeAnte(amount: 25)

        vm.cycleTripsBet()

        #expect(vm.stagedTrips == 5)
        #expect(vm.anteBet == 25)
        #expect(vm.blindBet == 25)
    }

    @Test("Cycling Trips skips an unaffordable step to off")
    func cycleTripsSkipsUnaffordableToOff() {
        // 15 chips: $5 OK, $10 OK, $25 unaffordable → should skip to off.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 15), bypassAnimation: true)

        vm.cycleTripsBet()
        #expect(vm.stagedTrips == 5)

        vm.cycleTripsBet()
        #expect(vm.stagedTrips == 10)

        vm.cycleTripsBet()
        #expect(vm.stagedTrips == 0)
        #expect(vm.errorMessage == nil)
    }

    @Test("Cycling Trips after the deal has no effect")
    func cycleTripsAfterDealIsNoOp() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // staged Trips = 5
        vm.deal()

        #expect(vm.phase == .preFlopDecision)
        #expect(vm.tripsBet == 5)
        let stagedBefore = vm.stagedTrips

        vm.cycleTripsBet()

        #expect(vm.stagedTrips == stagedBefore)
        #expect(vm.tripsBet == 5)
        #expect(vm.phase == .preFlopDecision)
    }

    @Test("Staged Trips is committed to the engine on deal")
    func dealCommitsStagedTrips() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5

        vm.deal()

        // 10 ante + 10 blind + 5 trips = 25 deducted.
        #expect(vm.tripsBet == 5)
        #expect(vm.chipBalance == 1_000 - 25)
    }

    @Test("newHand clears staged Trips for the next hand")
    func newHandClearsStagedTrips() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        vm.newHand()

        #expect(vm.stagedTrips == 0)
        #expect(vm.tripsBet == 0)
        #expect(vm.phase == .awaitingBets)
    }

    // MARK: - REBET

    @Test("Fresh view model has no rebet history and cannot rebet")
    func freshViewModelHasNoRebetState() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        #expect(vm.lastAnteBet == nil)
        #expect(vm.lastTripsBet == 0)
        #expect(vm.canRebet == false)
    }

    @Test("Resolving a hand records the Ante in lastAnteBet")
    func resolveRecordsLastAnte() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 25

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.phase == .handComplete)
        #expect(vm.lastAnteBet == 25)
    }

    @Test("Resolving with Trips placed records the Trips amount")
    func resolveRecordsLastTrips() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 10)
        #expect(vm.lastTripsBet == 5)
    }

    @Test("Resolving without Trips records lastTripsBet as 0")
    func resolveWithoutTripsRecordsZero() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastTripsBet == 0)
    }

    @Test("rebet restores Ante and Trips and deals")
    func rebetRestoresBetsAndDeals() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        // Now at .handComplete with lastAnteBet = 10, lastTripsBet = 5.
        #expect(vm.canRebet == true)
        vm.rebet()

        // deal() advances to .preFlopDecision with wagers committed.
        #expect(vm.phase == .preFlopDecision)
        #expect(vm.anteBet == 10)
        #expect(vm.blindBet == 10)
        #expect(vm.tripsBet == 5)
        #expect(vm.errorMessage == nil)
    }

    @Test("rebet skips Trips when the player can no longer afford it")
    func rebetSkipsUnaffordableTrips() {
        // Play one hand with Ante=10 and Trips=5 to seed lastAnteBet/lastTripsBet.
        // Then drop the store balance to exactly 2×Ante so the rebet can cover
        // Ante+Blind but not Trips.
        let store = InMemoryChipStore(chipBalance: 1_000, hasReceivedStarterBonus: true)
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.phase == .handComplete)
        #expect(vm.lastAnteBet == 10)
        #expect(vm.lastTripsBet == 5)

        // Reach into the shared store to force the affordability scenario.
        // This survives the next dispatch (collectAndReset) so rebet's
        // own balance read sees the reduced amount.
        store.chipBalance = 20

        vm.rebet()

        #expect(vm.phase == .preFlopDecision)
        #expect(vm.anteBet == 10)
        #expect(vm.blindBet == 10)
        #expect(vm.tripsBet == 0)
        #expect(vm.errorMessage == nil)
    }

    @Test("canRebet tracks the current balance against 2×lastAnteBet")
    func canRebetTracksBalance() {
        // Seed a completed hand with Ante=10. canRebet is a computed
        // property that reads the view model's current chipBalance, so
        // we verify both sides of the threshold by running a fresh hand
        // to force a sync at different balances.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 10)
        // Ample balance — clearly covers 2×10.
        #expect(vm.canRebet == true)
    }

    @Test("canRebet is false when balance falls below 2×Ante after next sync")
    func canRebetFalseWhenBalanceDrops() {
        // Play a hand to seed lastAnteBet=100, then drop the store to 50
        // and trigger a sync (via newHand) so canRebet refreshes.
        let store = InMemoryChipStore(chipBalance: 1_000, hasReceivedStarterBonus: true)
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = 100
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 100)

        store.chipBalance = 50
        // Any dispatch triggers a sync of chipBalance from the store.
        vm.newHand()

        #expect(vm.chipBalance == 50)
        #expect(vm.canRebet == false)
    }

    @Test("rebet no-ops when no prior hand was played")
    func rebetNoopWithoutHistory() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000), bypassAnimation: true)

        vm.rebet()

        #expect(vm.phase == .awaitingBets)
        #expect(vm.anteBet == 0)
        #expect(vm.playerHoleCards.isEmpty)
    }

    @Test("rebet with insufficient chips sets an error and does not deal")
    func rebetInsufficientChipsShowsError() {
        // Play a small hand so lastAnteBet is set, then attempt a rebet
        // from a near-empty balance.
        let store = InMemoryChipStore(chipBalance: 20, hasReceivedStarterBonus: true)
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.fold()

        // Balance is now 0 (Ante+Blind forfeited, no Trips).
        #expect(vm.chipBalance == 0)
        #expect(vm.lastAnteBet == 10)
        #expect(vm.canRebet == false)

        vm.rebet()

        #expect(vm.errorMessage != nil)
        #expect(vm.phase == .handComplete)
    }

    @Test("lastAnteBet and lastTripsBet update after each completed hand")
    func rebetStateUpdatesAcrossHands() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5_000), bypassAnimation: true)
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 10)
        #expect(vm.lastTripsBet == 5)

        // Rebet into a second hand, then change the Ante for a third.
        vm.rebet()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 10)
        #expect(vm.lastTripsBet == 5)

        vm.newHand()
        vm.stagedAnte = 25
        // Trips off this time.
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()

        #expect(vm.lastAnteBet == 25)
        #expect(vm.lastTripsBet == 0)
    }

    /// Most tests want to exercise the view model without the one-time
    /// starter bonus inflating their balances, so we hand the view model
    /// a store that already records the bonus as claimed.
    private static func bonusClaimed(chipBalance: Int) -> InMemoryChipStore {
        InMemoryChipStore(chipBalance: chipBalance, hasReceivedStarterBonus: true)
    }
}
