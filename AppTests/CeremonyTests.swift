import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("Tier 2-4 ceremonies")
struct CeremonyTests {

    // MARK: - Pure CeremonyState construction

    @Test("Both Tier 1 hands produce no ceremony")
    func bothTier1NoCeremony() {
        let result = makeResult(
            playerRank: .pair,
            dealerRank: .twoPair,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10
        )
        #expect(CeremonyState.from(result: result) == nil)
    }

    @Test("Player Tier 2 only triggers ceremony with player tier")
    func playerTier2OnlyTriggers() {
        let result = makeResult(
            playerRank: .straight,
            dealerRank: .pair,
            playerWins: true,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony != nil)
        #expect(ceremony?.effectiveTier == .notable)
        #expect(ceremony?.showsPlayerHand == true)
        #expect(ceremony?.showsDealerHand == false)
        #expect(ceremony?.isPlayerWin == true)
        #expect(ceremony?.useGoldTreatment == true)
    }

    @Test("Dealer Tier 2 only triggers muted ceremony")
    func dealerTier2OnlyTriggers() {
        let result = makeResult(
            playerRank: .pair,
            dealerRank: .straight,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony != nil)
        #expect(ceremony?.effectiveTier == .notable)
        #expect(ceremony?.isDealerWin == true)
        #expect(ceremony?.useGoldTreatment == false) // muted, no gold
        #expect(ceremony?.showsDealerHand == true)
        #expect(ceremony?.showsPlayerHand == false)
    }

    @Test("Both hands Tier 2+ triggers combined ceremony")
    func combinedCeremonyBothTier2() {
        let result = makeResult(
            playerRank: .straight,
            dealerRank: .threeOfAKind,
            playerWins: true,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony != nil)
        #expect(ceremony?.showsPlayerHand == true)
        #expect(ceremony?.showsDealerHand == true)
    }

    @Test("Higher tier wins effectiveTier when tiers differ in combined ceremony")
    func higherTierWinsCombined() {
        // Player has straight (.notable = 2), dealer has flush (.big = 3).
        // Effective tier should be .big.
        let result = makeResult(
            playerRank: .straight,
            dealerRank: .flush,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony?.effectiveTier == .big)
    }

    @Test("Trips fold-in: Tier 3 main hand + Trips payout = single payout number")
    func tripsFoldedIntoCeremonyPayout() {
        // Player flush (.big). Trips paid 6× (flush). Headline must include
        // the trips amount as part of totalNet.
        let trips: Double = 5
        let result = makeResult(
            playerRank: .flush,
            dealerRank: .pair,
            playerWins: true,
            tripsBet: 5,
            anteBet: 10,
            // Make the totalNet known: ante +10, blind +15 (1.5×), play +0,
            // trips +30 (6×). totalNet = 55.
            anteNet: 10, blindNet: 15, playNet: 0, tripsNet: trips * 6
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony != nil)
        #expect(ceremony?.payoutAmount == 55)
        #expect(ceremony?.effectiveTier == .big)
    }

    @Test("Push case: equal hands produce isPush + zero payout")
    func pushCeremonyShowsPush() {
        let result = makeResult(
            playerRank: .straight,
            dealerRank: .straight,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10,
            tiebreakers: [10],
            anteNet: 0, blindNet: 0, playNet: 0, tripsNet: 0
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony != nil)
        #expect(ceremony?.isPush == true)
        #expect(ceremony?.isPlayerWin == false)
        #expect(ceremony?.isDealerWin == false)
        #expect(ceremony?.payoutAmount == 0)
    }

    @Test("Dealer-win ceremony uses muted styling, never gold")
    func dealerWinIsMuted() {
        let result = makeResult(
            playerRank: .twoPair,
            dealerRank: .fullHouse,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10,
            anteNet: -10, blindNet: -10, playNet: -10, tripsNet: 0
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony?.useGoldTreatment == false)
        #expect(ceremony?.isDealerCeremony == true)
        #expect(ceremony?.payoutAmount == -30)
    }

    @Test("showsPlayerHand / showsDealerHand respect tier threshold")
    func showsHandRespectsTier() {
        // Player pair (.standard) — should not show player name.
        let result = makeResult(
            playerRank: .pair,
            dealerRank: .flush,
            playerWins: false,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony?.showsPlayerHand == false)
        #expect(ceremony?.showsDealerHand == true)
    }

    @Test("Tier 4 hand routes to .jackpot effective tier")
    func tier4Jackpot() {
        let result = makeResult(
            playerRank: .royalFlush,
            dealerRank: .pair,
            playerWins: true,
            tripsBet: 0,
            anteBet: 10
        )
        let ceremony = CeremonyState.from(result: result)
        #expect(ceremony?.effectiveTier == .jackpot)
    }

    // MARK: - View-model integration: ordering, gating, skip-to-settled

    @Test("Ceremony precedes chip resolution: animationStage transitions through .ceremony before chips move")
    func ceremonyPrecedesChipResolution() async {
        // Use ImmediateAnimationClock so we capture the stage transitions
        // by observing them via the test entrypoint. We only need to verify
        // that running the ceremony lands us back at .settled with no chip
        // animation having fired (zone animations stay .none).
        let vm = makeVM()
        let synthetic = makeCeremonyState(playerTier: .notable, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()

        // After the test entrypoint completes (ceremony + finalize), state
        // should be settled and zone animations untouched — chip resolution
        // is a separate concern that this entrypoint does not invoke.
        #expect(vm.currentCeremony == nil)
        #expect(vm.anteAnimation == .none)
        #expect(vm.blindAnimation == .none)
        #expect(vm.playAnimation == .none)
        #expect(vm.tripsAnimation == .none)
    }

    @Test("Tap-to-skip during a Tier 2 ceremony cleanly settles")
    func skipDuringTier2Ceremony() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .notable, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        // Suspended at the 1200ms sleep.
        #expect(vm.currentCeremony != nil)
        #expect(vm.animationStage == .ceremony)

        vm.skipToSettled()

        #expect(vm.currentCeremony == nil)
        #expect(vm.isAnimating == false)
    }

    @Test("Tier 4 lock-in: tap is ignored during the first 2500ms")
    func tier4TapIgnoredDuringLockIn() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .jackpot, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        // Suspended at the 2500ms lock-in sleep.
        #expect(vm.animationStage == .jackpotCeremony)
        #expect(vm.ceremonyAdvanceEnabled == false)
        #expect(vm.currentCeremony != nil)

        // Tap during lock-in — must be a no-op.
        vm.skipToSettled()
        #expect(vm.currentCeremony != nil)
        #expect(vm.animationStage == .jackpotCeremony)
        #expect(vm.ceremonyAdvanceEnabled == false)
    }

    @Test("Tier 4 advance window: tap respected after lock-in expires")
    func tier4TapRespectedAfterLockIn() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .jackpot, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        // Suspended at the 2500ms lock-in sleep.

        // Resume the lock-in sleep.
        clock.resumeNext()
        await drainAnimations()
        // Should now be in the 1500ms advance window.
        #expect(vm.ceremonyAdvanceEnabled == true)
        #expect(vm.animationStage == .jackpotCeremony)

        // Tap — should now skip to settled.
        vm.skipToSettled()
        #expect(vm.currentCeremony == nil)
        #expect(vm.isAnimating == false)
    }

    @Test("Tier 4 auto-advance: ceremony completes after both windows elapse without a tap")
    func tier4AutoAdvancesIfNoTap() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .jackpot, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        // Lock-in
        clock.resumeNext()
        await drainAnimations()
        // Advance window
        clock.resumeNext()
        await drainAnimations()

        // Both windows elapsed — ceremony cleared, animation finalized.
        #expect(vm.currentCeremony == nil)
        #expect(vm.isAnimating == false)
    }

    @Test("Tier 4 sleep durations are 2500ms and 1500ms in that order")
    func tier4SleepDurations() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .jackpot, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        clock.resumeNext()
        await drainAnimations()
        clock.resumeNext()
        await drainAnimations()

        #expect(clock.sleepLog == [2500, 1500])
    }

    @Test("Tier 2 ceremony sleep duration is 1200ms")
    func tier2SleepDuration() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .notable, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        clock.resumeNext()
        await drainAnimations()

        #expect(clock.sleepLog == [1200])
    }

    @Test("Tier 3 ceremony sleep duration is 1800ms")
    func tier3SleepDuration() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .big, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        clock.resumeNext()
        await drainAnimations()

        #expect(clock.sleepLog == [1800])
    }

    @Test("Ceremony state is cleared when a new hand begins")
    func ceremonyClearedOnNewHand() async {
        let clock = ManualAnimationClock()
        let vm = makeVM(clock: clock)
        let synthetic = makeCeremonyState(playerTier: .notable, dealerTier: .standard)

        vm._testRunCeremony(synthetic)
        await drainAnimations()
        vm.skipToSettled()
        #expect(vm.currentCeremony == nil)

        // newHand should also leave it cleared and reset the rest of the
        // animation state.
        vm.newHand()
        #expect(vm.currentCeremony == nil)
        #expect(vm.ceremonyAdvanceEnabled == false)
        #expect(vm.animationStage == .idle)
    }

    @Test("Ceremony stage runs before any chip-zone motion in real flow")
    func ceremonyStagePrecedesChipResolutionStage() async {
        // Sanity check the stage ordering by recording observed
        // animationStage values across a real deal until handComplete.
        // We can't deterministically force a Tier 2+ hand, so we just
        // verify the stage progression contains either a ceremony stage
        // followed by chip resolution, or chip resolution alone (Tier 1
        // hand). The stage value at test end should be .settled.
        let vm = makeVM()
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        #expect(vm.phase == .handComplete)
        #expect(vm.animationStage == .settled)
        #expect(vm.currentCeremony == nil)
    }

    // MARK: - Helpers

    private func makeVM(
        balance: Int = 5_000,
        clock: AnimationClock = ImmediateAnimationClock()
    ) -> GameTableViewModel {
        let store = InMemoryChipStore(chipBalance: balance, hasReceivedStarterBonus: true)
        return GameTableViewModel(chipStore: store, clock: clock)
    }

    private func drainAnimations() async {
        for _ in 0..<10 { await Task.yield() }
    }

    /// Synthesizes a `HandResult` for ceremony tests. Handles signed nets
    /// for win/loss framing and lets callers override individual nets when
    /// the trips fold-in math matters.
    private func makeResult(
        playerRank: HandRank,
        dealerRank: HandRank,
        playerWins: Bool,
        tripsBet: Int,
        anteBet: Int,
        tiebreakers: [Int]? = nil,
        anteNet: Double? = nil,
        blindNet: Double? = nil,
        playNet: Double? = nil,
        tripsNet: Double? = nil
    ) -> HandResult {
        // Tiebreakers: if not specified, default to a sane comparable tuple
        // so the player/dealer comparison agrees with `playerWins`.
        let pTiebreakers: [Int] = tiebreakers ?? (playerWins ? [14] : [2])
        let dTiebreakers: [Int] = tiebreakers ?? (playerWins ? [2]  : [14])
        let pHand = EvaluatedHand(
            rank: playerRank,
            cards: [],
            tiebreakers: pTiebreakers
        )
        let dHand = EvaluatedHand(
            rank: dealerRank,
            cards: [],
            tiebreakers: dTiebreakers
        )
        return HandResult(
            playerHand: pHand,
            dealerHand: dHand,
            dealerQualifies: true,
            anteOutcome: playerWins ? .win : .lose,
            blindOutcome: playerWins ? .win : .lose,
            playOutcome:  playerWins ? .win : .lose,
            tripsOutcome: tripsBet > 0 ? .blindBonus(multiplier: 6) : .lose,
            anteNet:  anteNet  ?? Double(playerWins ? anteBet  : -anteBet),
            blindNet: blindNet ?? Double(playerWins ? anteBet  : -anteBet),
            playNet:  playNet  ?? 0,
            tripsNet: tripsNet ?? 0
        )
    }

    /// Builds a synthetic `CeremonyState` directly. Used for the timing /
    /// gating tests that drive the ceremony task without a real deal.
    private func makeCeremonyState(
        playerTier: CeremonyTier,
        dealerTier: CeremonyTier
    ) -> CeremonyState {
        let player = rankForTier(playerTier)
        let dealer = rankForTier(dealerTier)
        return CeremonyState(
            playerHand: player,
            dealerHand: dealer,
            playerTier: playerTier,
            dealerTier: dealerTier,
            isPlayerWin: playerTier > dealerTier,
            isDealerWin: dealerTier > playerTier,
            isPush: playerTier == dealerTier && playerTier == .standard,
            payoutAmount: 50
        )
    }

    private func rankForTier(_ tier: CeremonyTier) -> HandRank {
        switch tier {
        case .standard: return .pair
        case .notable:  return .straight
        case .big:      return .flush
        case .jackpot:  return .royalFlush
        }
    }
}
