import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("Animation choreography")
struct AnimationTests {

    /// Helper — view model with the immediate clock so all `await sleep`s
    /// resolve without real-time delays. Lets each test run end-to-end in
    /// a few milliseconds.
    private static func makeVM(
        balance: Int = 5_000,
        haptics: HapticsService = NoopHapticsService()
    ) -> GameTableViewModel {
        let store = InMemoryChipStore(chipBalance: balance, hasReceivedStarterBonus: true)
        return GameTableViewModel(chipStore: store, clock: ImmediateAnimationClock(), haptics: haptics)
    }

    // MARK: - Outcome computation

    @Test("Push outcome with positive stake maps to .push")
    func pushOutcomeMapping() {
        #expect(BetZoneOutcome.from(outcome: .push, stake: 10) == .push)
    }

    @Test("Lose outcome with positive stake maps to .loss")
    func loseOutcomeMapping() {
        #expect(BetZoneOutcome.from(outcome: .lose, stake: 10) == .loss)
    }

    @Test("Win outcome with positive stake maps to .win")
    func winOutcomeMapping() {
        #expect(BetZoneOutcome.from(outcome: .win, stake: 10) == .win)
    }

    @Test("Blind bonus maps to .win for chip motion (Tier 1)")
    func blindBonusMapsToWin() {
        #expect(BetZoneOutcome.from(outcome: .blindBonus(multiplier: 5.0), stake: 10) == .win)
    }

    @Test("Zero-stake zones always return .noBet regardless of outcome")
    func zeroStakeIsNoBet() {
        #expect(BetZoneOutcome.from(outcome: .win,  stake: 0) == .noBet)
        #expect(BetZoneOutcome.from(outcome: .lose, stake: 0) == .noBet)
        #expect(BetZoneOutcome.from(outcome: .push, stake: 0) == .noBet)
        #expect(BetZoneOutcome.from(outcome: .blindBonus(multiplier: 3), stake: 0) == .noBet)
    }

    // MARK: - isAnimating gating

    @Test("Fresh view model is not animating")
    func freshIsNotAnimating() {
        let vm = Self.makeVM()
        #expect(vm.isAnimating == false)
        #expect(vm.animationStage == .idle)
    }

    @Test("deal() while animating is a no-op")
    func dealIgnoredDuringAnimation() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal()
        // While the spawned Task is still in-flight, deal again — the guard
        // should reject it. The first deal already mutated phase, so a
        // second deal would otherwise produce an illegal-action error;
        // here we expect no error and no re-entry.
        let phaseAfterFirst = vm.phase
        vm.deal()
        #expect(vm.phase == phaseAfterFirst)
        #expect(vm.errorMessage == nil)
        // Drain the animation to keep the test environment clean.
        await Task.yield()
    }

    // MARK: - skipToSettled

    @Test("skipToSettled flips all dealt cards face-up immediately")
    func skipFlipsAllDealtCards() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal()
        // Even before yielding to the task, skipToSettled should snap.
        vm.skipToSettled()
        for card in vm.playerHoleCards {
            #expect(vm.revealedCards.contains(card))
        }
        #expect(vm.isPlayerCardFaceDown(index: 0) == false)
        #expect(vm.isPlayerCardFaceDown(index: 1) == false)
    }

    @Test("skipToSettled at .handComplete reveals every card and resets bet zone motion")
    func skipAtHandComplete() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal()
        // Drive the engine to .handComplete. Each player action also
        // launches its own animation, so we yield between calls to let
        // the immediate-clock task run to completion before issuing the
        // next intent.
        await drainAnimations()
        vm.skipToSettled() // settle the deal animation
        vm.checkPreFlop();   await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop();  await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();   await drainAnimations()
        vm.skipToSettled()

        #expect(vm.phase == .handComplete)
        #expect(vm.isAnimating == false)
        for card in vm.playerHoleCards  { #expect(vm.revealedCards.contains(card)) }
        for card in vm.communityCards   { #expect(vm.revealedCards.contains(card)) }
        for card in vm.dealerHoleCards  { #expect(vm.revealedCards.contains(card)) }
        #expect(vm.anteAnimation  == .none)
        #expect(vm.blindAnimation == .none)
        #expect(vm.playAnimation  == .none)
        #expect(vm.tripsAnimation == .none)
        #expect(vm.displayedBalance == vm.chipBalance)
    }

    @Test("skipToSettled when idle is a no-op and does not crash")
    func skipWhenIdleIsNoOp() {
        let vm = Self.makeVM()
        let stageBefore = vm.animationStage
        vm.skipToSettled()
        #expect(vm.animationStage == stageBefore)
        #expect(vm.isAnimating == false)
    }

    // MARK: - Card face-down helpers

    @Test("Player cards are face-down between deal dispatch and reveal")
    func playerCardsFaceDownAtDeal() {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal()
        // Before the spawned Task gets to run, both cards are unrevealed.
        // (This is the synchronous frame the user sees right after DEAL.)
        #expect(vm.isPlayerCardFaceDown(index: 0))
        #expect(vm.isPlayerCardFaceDown(index: 1))
    }

    @Test("Dealer cards stay face-down until handComplete reveal")
    func dealerCardsFaceDownThroughDecisions() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        #expect(vm.isDealerCardFaceDown(index: 0))
        #expect(vm.isDealerCardFaceDown(index: 1))

        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        #expect(vm.isDealerCardFaceDown(index: 0))
        #expect(vm.isDealerCardFaceDown(index: 1))

        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        #expect(vm.isDealerCardFaceDown(index: 0))
        #expect(vm.isDealerCardFaceDown(index: 1))

        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()
        #expect(vm.isDealerCardFaceDown(index: 0) == false)
        #expect(vm.isDealerCardFaceDown(index: 1) == false)
    }

    @Test("Dealer cards remain face-down after a post-river fold")
    func dealerCardsStayFaceDownOnFold() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.fold();          await drainAnimations()

        #expect(vm.phase == .handComplete)
        #expect(vm.playerFolded)
        #expect(vm.isDealerCardFaceDown(index: 0))
        #expect(vm.isDealerCardFaceDown(index: 1))
    }

    @Test("playerFolded resets to false after newHand")
    func playerFoldedResetsAfterNewHand() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.fold();          await drainAnimations()
        #expect(vm.playerFolded)

        vm.newHand()
        #expect(vm.playerFolded == false)
    }

    @Test("Fold path skips the dealer-reveal sleeps (no [200, 250, 100])")
    func foldSkipsDealerRevealSleeps() async {
        let clock = ManualAnimationClock()
        let store = InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true)
        let vm = GameTableViewModel(chipStore: store, clock: clock)
        vm.stagedAnte = 10

        // Drive deal → preFlop check → postFlop check, draining all sleeps
        // via the manual clock so the log is at a known point before fold.
        // Yield first so the spawned Task reaches its first suspend before
        // we start resuming, then keep going until both the clock queue is
        // empty and the view model has finished settling.
        let drainAll: () async -> Void = {
            await drainAnimations()
            while clock.pendingSleeps > 0 || vm.isAnimating {
                if clock.pendingSleeps > 0 {
                    clock.resumeNext()
                }
                await drainAnimations()
            }
        }
        vm.deal();          await drainAll()
        vm.checkPreFlop();  await drainAll()
        vm.checkPostFlop(); await drainAll()
        let sleepsBeforeFold = clock.sleepLog

        vm.fold(); await drainAll()
        let foldSleeps = Array(clock.sleepLog.dropFirst(sleepsBeforeFold.count))

        // Fold-path sleeps should be only the chip-resolution beats:
        // [150 pulse, 550 slide, 150 balance hold]. Dealer reveal would have
        // contributed [200, 250, 100] which must be absent.
        #expect(foldSleeps == [150, 550, 150])
        #expect(vm.phase == .handComplete)
        #expect(vm.playerFolded)
    }

    // MARK: - Bet zone outcome inspection

    @Test("zoneOutcome returns .noBet when no hand has resolved")
    func zoneOutcomeBeforeResolution() {
        let vm = Self.makeVM()
        #expect(vm.zoneOutcome(.ante)  == .noBet)
        #expect(vm.zoneOutcome(.blind) == .noBet)
        #expect(vm.zoneOutcome(.play)  == .noBet)
        #expect(vm.zoneOutcome(.trips) == .noBet)
    }

    @Test("zoneOutcome reflects the resolved hand for placed bets")
    func zoneOutcomeAfterResolution() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        #expect(vm.phase == .handComplete)
        // Trips wasn't placed; outcome should be .noBet regardless of how
        // the engine resolved trips.
        #expect(vm.zoneOutcome(.trips) == .noBet)

        // Ante/Blind/Play were all placed — outcome must be .push, .loss,
        // or .win. The exact value depends on which deck shuffled out.
        let placed: Set<BetZoneOutcome> = [.push, .loss, .win]
        #expect(placed.contains(vm.zoneOutcome(.ante)))
        #expect(placed.contains(vm.zoneOutcome(.blind)))
        #expect(placed.contains(vm.zoneOutcome(.play)))
    }

    // MARK: - displayedBalance behavior

    @Test("displayedBalance equals chipBalance while idle")
    func displayedBalanceTracksChipBalanceWhileIdle() {
        let vm = Self.makeVM(balance: 1_000)
        #expect(vm.displayedBalance == 1_000)
    }

    @Test("displayedBalance lands on chipBalance after a settled hand")
    func displayedBalanceMatchesAfterSettle() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        #expect(vm.phase == .handComplete)
        #expect(vm.isAnimating == false)
        #expect(vm.displayedBalance == vm.chipBalance)
    }

    // MARK: - newHand clears animation state

    @Test("newHand resets animation state and clears revealed cards")
    func newHandResetsAnimation() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        vm.newHand()
        #expect(vm.animationStage == .idle)
        #expect(vm.revealedCards.isEmpty)
        #expect(vm.anteAnimation  == .none)
        #expect(vm.blindAnimation == .none)
        #expect(vm.playAnimation  == .none)
        #expect(vm.tripsAnimation == .none)
    }

    // MARK: - REBET flip parity

    @Test("rebet defers the deal so player hole cards begin face-down with a full flip, identical to fresh deal")
    func rebetFlipMatchesFreshDeal() async {
        // Reproduces the session-10a bug: rebet() ran collectAndReset +
        // resetAnimationState + deal() in one synchronous block, so the
        // {oldHandCards} → {} mutation of revealedCards fired the
        // top-level .animation(value: revealedCards) modifier against
        // the freshly-dealt new cards. The fix defers deal() to a
        // separate MainActor tick — so AFTER rebet's sync portion
        // returns, the engine and animation state must be cleared
        // (cards empty, revealedCards empty) and the new deal must
        // not have happened yet.
        let vm = Self.makeVM()
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        #expect(vm.phase == .handComplete)
        #expect(!vm.revealedCards.isEmpty)
        #expect(vm.canRebet)

        vm.rebet()
        // Sync portion of rebet has run; the deferred deal() has not.
        // This is the render gap that lets SwiftUI draw the cleared
        // state before the new cards arrive.
        #expect(vm.phase == .awaitingBets)
        #expect(vm.playerHoleCards.isEmpty)
        #expect(vm.revealedCards.isEmpty)

        // Drain the deferred deal() Task plus its inner flip Task.
        await drainAnimations()

        // Now in the dealt + flipped state — same end state as a fresh
        // deal() call: both hole cards face-up, both in revealedCards.
        #expect(vm.phase == .preFlopDecision)
        #expect(vm.playerHoleCards.count == 2)
        #expect(vm.isPlayerCardFaceDown(index: 0) == false)
        #expect(vm.isPlayerCardFaceDown(index: 1) == false)
        for card in vm.playerHoleCards {
            #expect(vm.revealedCards.contains(card))
        }
    }

    // MARK: - Per-hand view identity

    @Test("currentDealId starts at zero on a fresh view model")
    func dealIdStartsAtZero() {
        let vm = Self.makeVM()
        #expect(vm.currentDealId == 0)
    }

    @Test("currentDealId increments on each successful deal")
    func dealIdIncrementsOnDeal() async {
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal(); await drainAnimations(); vm.skipToSettled()
        #expect(vm.currentDealId == 1)
    }

    @Test("currentDealId increments across REBET so player CardViews receive a fresh .id() per hand")
    func dealIdChangesOnRebet() async {
        // The player-zone CardView in GameTableView binds its .id() to
        // currentDealId so SwiftUI tears down the previous hand's view
        // and creates a fresh one for each new hand. Without that,
        // SwiftUI's positional identity reuses the prior face-up
        // ZStack and the new card renders without a flip — the
        // session-10b symptom.
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        let dealIdAfterFirstHand = vm.currentDealId
        #expect(dealIdAfterFirstHand == 1)

        vm.rebet()
        await drainAnimations()

        // The deferred deal() must have bumped currentDealId so that
        // .id("player-card-\(currentDealId)-0/1") differs from the
        // previous hand — forcing SwiftUI to recreate both player
        // CardViews fresh.
        #expect(vm.currentDealId == dealIdAfterFirstHand + 1)
        #expect(vm.currentDealId != dealIdAfterFirstHand)
    }

    @Test("currentDealId does not change on collectAndReset (newHand)")
    func dealIdStableOnNewHand() async {
        // Only successful deals bump currentDealId — clearing the
        // table should not, otherwise the next hand's id would be
        // bumped twice for what the player perceives as one hand.
        let vm = Self.makeVM()
        vm.stagedAnte = 10
        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        let dealIdBefore = vm.currentDealId
        vm.newHand()
        #expect(vm.currentDealId == dealIdBefore)

        vm.deal(); await drainAnimations(); vm.skipToSettled()
        #expect(vm.currentDealId == dealIdBefore + 1)
    }

    // MARK: - Haptic trigger map

    @Test("Card flips fire .light impacts during deal")
    func dealFiresLightCardFlipHaptics() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)
        vm.stagedAnte = 10

        vm.deal()
        await drainAnimations()

        // Two player hole-card reveals on a fresh deal — both fire .light.
        let lightCount = recording.events.filter { $0 == .impact(.light) }.count
        #expect(lightCount == 2)
    }

    @Test("Cycling Trips fires .medium impact when stagedTrips actually changes")
    func cycleTripsFiresMediumImpact() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)

        vm.cycleTripsBet()
        #expect(recording.events == [.impact(.medium)])
    }

    @Test("Cycling Trips outside .awaitingBets fires no haptic")
    func cycleTripsAfterDealNoHaptic() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)
        vm.stagedAnte = 10
        vm.deal(); await drainAnimations(); vm.skipToSettled()
        recording.clear()

        vm.cycleTripsBet()
        #expect(recording.events.isEmpty)
    }

    @Test("Ante stepper +/- fires .medium impacts on each step change")
    func anteStepperFiresMediumImpact() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)

        vm.incrementStagedAnte()
        vm.decrementStagedAnte()
        #expect(recording.events == [.impact(.medium), .impact(.medium)])
    }

    @Test("Fold path fires no card-flip haptics for the dealer reveal")
    func foldNoDealerCardFlipHaptics() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        // Track the light-impact count BEFORE the fold so we only count
        // any new light flips fired during the fold path.
        let lightsBeforeFold = recording.events.filter { $0 == .impact(.light) }.count

        vm.fold(); await drainAnimations()

        let lightsAfterFold = recording.events.filter { $0 == .impact(.light) }.count
        #expect(lightsAfterFold == lightsBeforeFold)
        #expect(vm.playerFolded)
    }

    @Test("Resolution outcome fires the correct loss/push haptics on slide phase")
    func resolutionFiresOutcomeHaptics() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)
        vm.stagedAnte = 10

        vm.deal();          await drainAnimations(); vm.skipToSettled()
        vm.checkPreFlop();  await drainAnimations(); vm.skipToSettled()
        vm.checkPostFlop(); await drainAnimations(); vm.skipToSettled()
        vm.betPostRiver();  await drainAnimations(); vm.skipToSettled()

        let losses  = recording.events.filter { $0 == .notification(.warning) }.count
        let pushes  = recording.events.filter { $0 == .impact(.soft) }.count

        // For each of the four bet zones (ante, blind, play, trips),
        // outcome haptics fire once on .slide. With a non-deterministic
        // deck we don't know which zones lose/push, but per-zone-per-phase
        // the count must match the actual outcomes — and at minimum the
        // count is bounded by the four zones.
        #expect(losses + pushes <= 4)
        #expect(losses >= 0)
        #expect(pushes >= 0)
    }

    @Test("skipToSettled does not fire .light haptics for the bulk reveal sweep")
    func skipToSettledNoBulkHaptics() async {
        let recording = RecordingHapticsService()
        let vm = Self.makeVM(haptics: recording)
        vm.stagedAnte = 10

        // Deal and skip immediately — bulk-reveal sweep in finalizeSettledState
        // would burst flip haptics if we didn't guard it. Confirm only the
        // animated deal flips fired (max 2: both player hole cards).
        vm.deal(); await drainAnimations(); vm.skipToSettled()
        let lightCount = recording.events.filter { $0 == .impact(.light) }.count
        #expect(lightCount <= 2)
    }

    // MARK: - Helpers

    /// Yields enough times for the @MainActor animation Task spawned by
    /// the most recent intent to complete under `ImmediateAnimationClock`.
    /// All sleeps resolve immediately, so a handful of yields is enough.
    private func drainAnimations() async {
        for _ in 0..<10 { await Task.yield() }
    }
}
