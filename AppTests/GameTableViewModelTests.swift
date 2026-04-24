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

    // MARK: - Trips side bet cycling

    @Test("Cycling Trips from off places $5")
    func cycleTripsFromOffPlacesFive() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        vm.cycleTripsBet()

        #expect(vm.stagedTrips == 5)
        #expect(vm.displayedTripsBet == 5)
    }

    @Test("Cycling Trips from $5 advances to $10")
    func cycleTripsAdvancesToTen() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10

        #expect(vm.stagedTrips == 10)
    }

    @Test("Cycling Trips from $10 advances to $25")
    func cycleTripsAdvancesToTwentyFive() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10
        vm.cycleTripsBet() // 25

        #expect(vm.stagedTrips == 25)
    }

    @Test("Cycling Trips from $25 clears back to off")
    func cycleTripsWrapsToOff() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))

        vm.cycleTripsBet() // 5
        vm.cycleTripsBet() // 10
        vm.cycleTripsBet() // 25
        vm.cycleTripsBet() // off

        #expect(vm.stagedTrips == 0)
        #expect(vm.displayedTripsBet == 0)
    }

    @Test("Cycling Trips does not affect Ante or Blind")
    func cycleTripsIndependentOfAnteAndBlind() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
        vm.placeAnte(amount: 25)

        vm.cycleTripsBet()

        #expect(vm.stagedTrips == 5)
        #expect(vm.anteBet == 25)
        #expect(vm.blindBet == 25)
    }

    @Test("Cycling Trips skips an unaffordable step to off")
    func cycleTripsSkipsUnaffordableToOff() {
        // 15 chips: $5 OK, $10 OK, $25 unaffordable → should skip to off.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 15))

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
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
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
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
        vm.stagedAnte = 10
        vm.cycleTripsBet() // 5

        vm.deal()

        // 10 ante + 10 blind + 5 trips = 25 deducted.
        #expect(vm.tripsBet == 5)
        #expect(vm.chipBalance == 1_000 - 25)
    }

    @Test("newHand clears staged Trips for the next hand")
    func newHandClearsStagedTrips() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 1_000))
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

    /// Most tests want to exercise the view model without the one-time
    /// starter bonus inflating their balances, so we hand the view model
    /// a store that already records the bonus as claimed.
    private static func bonusClaimed(chipBalance: Int) -> InMemoryChipStore {
        InMemoryChipStore(chipBalance: chipBalance, hasReceivedStarterBonus: true)
    }
}
