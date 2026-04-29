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

    @Test("formattedBalance uses currency formatting")
    func formattedBalanceUsesCommas() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 5_000), bypassAnimation: true)

        let formatted = vm.formattedBalance
        #expect(formatted.contains("5,000"))
    }

    // MARK: - Ante bet cycling (Session 15b: table-aware via .table10 default)

    @Test("Cycling Ante from initial $10 advances to $15")
    func cycleAnteFromMinimumAdvancesToNextStep() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // Fresh init starts stagedAnte at the table's minimum ($10 on .table10).
        #expect(vm.stagedAnte == 10)

        vm.cycleAnteBet()

        #expect(vm.stagedAnte == 15)
    }

    @Test("Cycling Ante advances through every step in order")
    func cycleAnteAdvancesThroughEachStep() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // .table10's anteCycle: [10, 15, 25, 50, 100, 0]. Starting at $10
        // (the minimum), each cycle advances one position then wraps.
        let expected = [15, 25, 50, 100, 0, 10, 15]

        for step in expected {
            vm.cycleAnteBet()
            #expect(vm.stagedAnte == step)
        }
    }

    @Test("Cycling Ante from $0 wraps back to the table minimum")
    func cycleAnteWrapsFromZeroToMinimum() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // Walk to $0 ($10 → $15 → $25 → $50 → $100 → $0).
        for _ in 0..<5 { vm.cycleAnteBet() }
        #expect(vm.stagedAnte == 0)

        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 10)
    }

    @Test("Blind value mirrors Ante after each cycle tap")
    func cycleAnteBlindMirrorsAnte() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // The Blind bet zone displays `stagedAnte` while in `.awaitingBets`,
        // matching the engine invariant Blind == Ante that placeAnte enforces
        // on deal. Verify the cycle drives both the Ante value the deal will
        // commit and the Blind value the player sees.
        let cycle = [15, 25, 50, 100, 0, 10]

        for step in cycle {
            vm.cycleAnteBet()
            #expect(vm.stagedAnte == step)
        }

        // Walk through a deal to confirm the engine still enforces Blind = Ante
        // at the value we landed on in the cycle.
        vm.cycleAnteBet() // → 15
        vm.deal()
        #expect(vm.anteBet == 15)
        #expect(vm.blindBet == 15)
    }

    @Test("Cycling Ante skips an unaffordable step to $0")
    func cycleAnteSkipsUnaffordableToZero() {
        // 80 chips at .table10: $10 (2× = $20 OK), $15 ($30 OK), $25 ($50 OK),
        // $50 ($100 unaffordable) → falls back to $0 (cleared state).
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 80), bypassAnimation: true)
        #expect(vm.stagedAnte == 10)

        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 15)

        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 25)

        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 0)
        #expect(vm.errorMessage == nil)
    }

    @Test("Cycling Ante does not affect Trips")
    func cycleAnteIndependentOfTrips() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        vm.cycleTripsBet() // stagedTrips = 5

        vm.cycleAnteBet() // stagedAnte 10 → 15

        #expect(vm.stagedAnte == 15)
        #expect(vm.stagedTrips == 5)
    }

    @Test("Cycling Ante after the deal has no effect")
    func cycleAnteAfterDealIsNoOp() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // Ante starts at the table minimum ($10 on .table10); deal commits it.
        vm.deal()
        #expect(vm.phase == .preFlopDecision)
        let stagedBefore = vm.stagedAnte

        vm.cycleAnteBet()

        #expect(vm.stagedAnte == stagedBefore)
        #expect(vm.anteBet == 10)
        #expect(vm.phase == .preFlopDecision)
    }

    @Test("REBET preserves the prior Ante value across hands")
    func rebetPreservesAnteAcrossHands() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        vm.stagedAnte = 100

        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()
        #expect(vm.phase == .handComplete)
        #expect(vm.lastAnteBet == 100)

        vm.rebet()

        // After REBET the new hand is in flight with the prior $100 Ante still
        // staged — not reset to $0 and not reset to the $5 cycle floor.
        #expect(vm.stagedAnte == 100)
        #expect(vm.anteBet == 100)
        #expect(vm.blindBet == 100)
        #expect(vm.phase == .preFlopDecision)
    }

    @Test("DEAL is rejected when Ante is at the $0 cycle position")
    func dealRefusesWhenAnteIsZero() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        // Walk to $0 in the cycle.
        for _ in 0..<5 { vm.cycleAnteBet() }
        #expect(vm.stagedAnte == 0)

        // canDeal must be false at $0; the engine itself also refuses
        // placeAnte(0), so a direct deal() leaves the phase untouched.
        #expect(vm.canDeal == false)

        vm.deal()
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
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
        // Session 12d gate (Session 15b table-aware): each Trips step must
        // fit on top of the worst-case main bet (6 × stagedAnte). On .table10
        // the floor at Ante=$10 is $60. Balance $70 covers $5 ($65) and $10
        // ($70), but $25 ($85) overshoots — that step falls back to "off".
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 70), bypassAnimation: true)

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
        // from a near-empty balance. `hasReceivedSecondChanceBonus: true`
        // skips the Session 12b first-bust auto-award path so this test
        // continues to exercise the rebet-with-insufficient-chips flow
        // — second-bust still fires (the modal appears and the engine is
        // collected to `.awaitingBets`), and rebet now refuses because
        // the engine is no longer in `.handComplete`.
        let store = InMemoryChipStore(
            chipBalance: 20,
            hasReceivedStarterBonus: true,
            hasReceivedSecondChanceBonus: true
        )
        let vm = GameTableViewModel(chipStore: store, bypassAnimation: true)
        vm.stagedAnte = 10
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.fold()

        // Balance is 0 and the second-bust modal is up; collectAndReset
        // ran inside the bust handler, so the engine is at `.awaitingBets`.
        #expect(vm.chipBalance == 0)
        #expect(vm.lastAnteBet == 10)
        #expect(vm.canRebet == false)
        #expect(vm.bustModal == .secondBust)

        vm.rebet()

        #expect(vm.errorMessage != nil)
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

    // MARK: - DEAL gate (Session 12d affordability — table-aware in 15b)

    @Test("DEAL is enabled when chipBalance equals 6× stagedAnte (boundary)")
    func dealEnabledAtSixTimesAnte() {
        // 6× covers Ante + Blind + 4× pre-flop Play — the worst case
        // the player could be locked into after dealing. At exactly 6×
        // the table minimum ($10 on .table10) the player can complete
        // every betting branch.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 60), bypassAnimation: true)
        #expect(vm.stagedAnte == 10)
        #expect(vm.canAffordDeal == true)
    }

    @Test("DEAL is disabled when chipBalance falls one chip short of 6× stagedAnte")
    func dealDisabledJustBelowBoundary() {
        // 59 chips at Ante=10 on .table10 — short of 6×$10 = $60. The
        // Session 12d gate refuses DEAL.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 59), bypassAnimation: true)
        #expect(vm.stagedAnte == 10)
        #expect(vm.canAffordDeal == false)
    }

    @Test("DEAL is disabled when stagedAnte is high enough that 4× Play would not fit")
    func dealDisabledWhenWorstCasePlayUnaffordable() {
        // 100 chips can cover Ante + Blind at $25 ($50 needed) but not
        // the worst-case round (6 × $25 = $150). Pre-Session 12d this
        // would have allowed DEAL; the new gate refuses.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 100), bypassAnimation: true)
        vm.cycleAnteBet() // 10 → 15
        vm.cycleAnteBet() // 15 → 25
        #expect(vm.stagedAnte == 25)
        #expect(vm.canAffordDeal == false)
    }

    @Test("DEAL re-enables as the player cycles Ante back down to an affordable value")
    func dealReEnablesAfterCyclingAnteDown() {
        // 60 chips: only $10 Ante (worst case $60) is affordable. Cycling
        // walks 10 → 15 → 25 → 50 → 0 → 10. Each non-zero step above $10
        // exceeds 6× — DEAL stays disabled until the cycle wraps back to
        // the table minimum.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 60), bypassAnimation: true)
        #expect(vm.stagedAnte == 10)
        #expect(vm.canAffordDeal == true)

        vm.cycleAnteBet() // 10 → 15 (2×15=30 lands; 6×15=90 > 60)
        #expect(vm.stagedAnte == 15)
        #expect(vm.canAffordDeal == false)

        vm.cycleAnteBet() // 15 → 25 (2×25=50 lands; 6×25=150 > 60)
        #expect(vm.stagedAnte == 25)
        #expect(vm.canAffordDeal == false)

        vm.cycleAnteBet() // 25 → 50 (2×50=100 > 60 → falls to $0)
        #expect(vm.stagedAnte == 0)
        #expect(vm.canAffordDeal == false)

        vm.cycleAnteBet() // 0 → 10 (wrap; 6×10=60 lands)
        #expect(vm.stagedAnte == 10)
        #expect(vm.canAffordDeal == true)
    }

    // MARK: - Trips affordability gate (Session 12d — table-aware in 15b)

    @Test("Trips zone is interactive when balance covers the worst-case main bet plus the smallest Trips step")
    func tripsInteractiveWhenAffordable() {
        // 65 chips at Ante=10 on .table10: 6×10 + 5 = 65. The smallest
        // Trips step ($5) just fits, so the zone accepts taps.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 65), bypassAnimation: true)
        #expect(vm.canAffordDeal == true)
        #expect(vm.isTripsZoneInteractive == true)
    }

    @Test("Trips zone disables when balance covers main bet but not the smallest Trips step")
    func tripsZoneDisabledWhenMainAffordableButTripsNot() {
        // 64 chips at Ante=10: covers 6×10 = 60 (DEAL OK) but not 60+5 = 65
        // (no Trips step affordable). The zone goes inert.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 64), bypassAnimation: true)
        #expect(vm.canAffordDeal == true)
        #expect(vm.isTripsZoneInteractive == false)
    }

    @Test("Cycling Ante up force-clears Trips when the new total overshoots balance")
    func anteCycleForceClearsTrips() {
        // Balance 100 on .table10: at Ante=$10 with Trips=$25, 60+25=85
        // ≤ 100 (Trips OK). Cycle Ante 10 → 15: 6×15+25 = 115 > 100, so
        // Trips must clear.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 100), bypassAnimation: true)
        vm.cycleTripsBet(); vm.cycleTripsBet(); vm.cycleTripsBet()
        #expect(vm.stagedTrips == 25)

        vm.cycleAnteBet() // 10 → 15 (2×15=30 lands); 6×15+25=115 > 100 → force-clear
        #expect(vm.stagedAnte == 15)
        #expect(vm.stagedTrips == 0)
    }

    @Test("Cycling Ante down does NOT auto-restore a previously-cleared Trips value")
    func anteCycleDownDoesNotRestoreTrips() {
        // Balance 100 lets Trips=$25 sit on top of Ante=$10 (60 + 25 ≤ 100)
        // but not on top of Ante=$15 (115 > 100) — so cycling Ante up
        // force-clears Trips. Cycling Ante back down to $10 must NOT
        // auto-restore the prior Trips value.
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 100), bypassAnimation: true)
        vm.cycleTripsBet(); vm.cycleTripsBet(); vm.cycleTripsBet() // 25
        vm.cycleAnteBet() // 10 → 15, force-clears Trips
        #expect(vm.stagedAnte == 15)
        #expect(vm.stagedTrips == 0)

        // Walk Ante back to $10: 15 → 25 (2×25=50 OK) → 50 (2×50=100 OK)
        // → 100 (2×100=200 unaffordable, falls to 0) → 10. Four cycle taps.
        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 25)
        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 50)
        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 0)
        vm.cycleAnteBet()
        #expect(vm.stagedAnte == 10)

        // Trips zone is once again affordable at Ante=$10 (100 >= 65),
        // but stagedTrips stays at $0 — no auto-restore.
        #expect(vm.isTripsZoneInteractive == true)
        #expect(vm.stagedTrips == 0)
    }

    // MARK: - Table-aware cycle ranges (Session 15b)

    @Test("Default init uses .table10 and starts stagedAnte at $10")
    func defaultInitUsesTableTen() {
        let vm = GameTableViewModel(chipStore: Self.bonusClaimed(chipBalance: 10_000), bypassAnimation: true)
        #expect(vm.tableConfig == .table10)
        #expect(vm.stagedAnte == 10)
        #expect(vm.anteCycle == [10, 15, 25, 50, 100, 0])
        #expect(vm.tripsCycle == [0, 5, 10, 25])
    }

    @Test("Initializing with .table25 exposes the $25 ante cycle")
    func initWithTable25() {
        let vm = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 10_000),
            tableConfig: .table25,
            bypassAnimation: true
        )
        #expect(vm.tableConfig == .table25)
        #expect(vm.stagedAnte == 25)
        #expect(vm.anteCycle == [25, 50, 100, 250, 500, 0])
        #expect(vm.tripsCycle == [0, 5, 10, 25, 50])
    }

    @Test("Initializing with .table50 exposes the $50 ante cycle")
    func initWithTable50() {
        let vm = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 10_000),
            tableConfig: .table50,
            bypassAnimation: true
        )
        #expect(vm.tableConfig == .table50)
        #expect(vm.stagedAnte == 50)
        #expect(vm.anteCycle == [50, 100, 200, 500, 1000, 0])
        #expect(vm.tripsCycle == [0, 10, 25, 50, 100])
    }

    @Test("Cycling Ante from $0 lands on the table's minimum, not a fixed floor")
    func zeroWrapsToTableMinimum() {
        let vm10 = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 10_000),
            tableConfig: .table10,
            bypassAnimation: true
        )
        for _ in 0..<5 { vm10.cycleAnteBet() } // walk to $0
        #expect(vm10.stagedAnte == 0)
        vm10.cycleAnteBet()
        #expect(vm10.stagedAnte == 10)

        let vm25 = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 10_000),
            tableConfig: .table25,
            bypassAnimation: true
        )
        for _ in 0..<5 { vm25.cycleAnteBet() }
        #expect(vm25.stagedAnte == 0)
        vm25.cycleAnteBet()
        #expect(vm25.stagedAnte == 25)
    }

    @Test("DEAL gate respects 6× the table-specific stagedAnte")
    func dealGateRespectsTableMinimum() {
        // Table25 minimum = $25 → DEAL needs ≥ $150. Test the boundary
        // on both sides.
        let belowBoundary = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 149),
            tableConfig: .table25,
            bypassAnimation: true
        )
        #expect(belowBoundary.stagedAnte == 25)
        #expect(belowBoundary.canAffordDeal == false)

        let atBoundary = GameTableViewModel(
            chipStore: Self.bonusClaimed(chipBalance: 150),
            tableConfig: .table25,
            bypassAnimation: true
        )
        #expect(atBoundary.stagedAnte == 25)
        #expect(atBoundary.canAffordDeal == true)
    }

    @Test("Trips floor on .table50 is $10 (not $5)")
    func tripsFloorOnTableFifty() {
        // .table50's tripsCycle starts at $10. The Trips zone should
        // gate on 6×Ante + $10, not 6×Ante + $5.
        let store = Self.bonusClaimed(chipBalance: 309)
        let vm = GameTableViewModel(chipStore: store, tableConfig: .table50, bypassAnimation: true)
        // 6×50 = 300; 300 + 10 = 310. Balance 309 cannot cover the
        // smallest Trips step on top of the worst-case main bet.
        #expect(vm.canAffordDeal == true)
        #expect(vm.isTripsZoneInteractive == false)

        let storeOK = Self.bonusClaimed(chipBalance: 310)
        let vmOK = GameTableViewModel(chipStore: storeOK, tableConfig: .table50, bypassAnimation: true)
        #expect(vmOK.isTripsZoneInteractive == true)
    }

    /// Most tests want to exercise the view model without the one-time
    /// starter bonus inflating their balances, so we hand the view model
    /// a store that already records the bonus as claimed.
    private static func bonusClaimed(chipBalance: Int) -> InMemoryChipStore {
        InMemoryChipStore(chipBalance: chipBalance, hasReceivedStarterBonus: true)
    }
}
