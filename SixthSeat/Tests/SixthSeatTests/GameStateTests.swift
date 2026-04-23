import Testing
@testable import SixthSeat

@Suite("GameState")
struct GameStateTests {

    /// Every test uses an `InMemoryChipStore` so nothing leaks into the
    /// real `UserDefaults` database.
    private static func newGame(startingChips: Int = 5_000) -> (GameState, InMemoryChipStore) {
        let store = InMemoryChipStore(chipBalance: startingChips)
        return (GameState(chipStore: store), store)
    }

    // MARK: - Initial state

    @Test("New game starts at .awaitingBets with 5000 chips and empty hands")
    func newGameInitialState() {
        let (game, _) = Self.newGame()
        #expect(game.phase == .awaitingBets)
        #expect(game.chipBalance == 5000)
        #expect(game.anteBet == 0)
        #expect(game.blindBet == 0)
        #expect(game.tripsBet == 0)
        #expect(game.playBet == 0)
        #expect(game.playerFolded == false)
        #expect(game.playerHoleCards.isEmpty)
        #expect(game.dealerHoleCards.isEmpty)
        #expect(game.communityCards.isEmpty)
        #expect(game.lastHandResult == nil)
    }

    @Test("Custom starting chip count is honored")
    func customStartingChips() {
        let (game, _) = Self.newGame(startingChips: 1234)
        #expect(game.chipBalance == 1234)
    }

    // MARK: - Pre-deal wagers

    @Test("Placing Ante sets Blind to the same amount and deducts both")
    func anteSetsBlindAndDeducts() {
        let (game, _) = Self.newGame()
        let result = game.perform(.placeAnte(amount: 10))
        #expect(result.isSuccess)
        #expect(game.anteBet == 10)
        #expect(game.blindBet == 10)
        #expect(game.chipBalance == 5000 - 20)
    }

    @Test("Re-placing Ante refunds the previous Ante/Blind before deducting the new amount")
    func antePlacementIsRevisable() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.placeAnte(amount: 25))
        #expect(game.anteBet == 25)
        #expect(game.blindBet == 25)
        #expect(game.chipBalance == 5000 - 50)
    }

    @Test("Ante of zero or less is rejected as invalidBetAmount")
    func anteMustBePositive() {
        let (game, _) = Self.newGame()
        let result = game.perform(.placeAnte(amount: 0))
        guard case .failure(.invalidBetAmount) = result else {
            Issue.record("expected .invalidBetAmount, got \(result)")
            return
        }
    }

    @Test("Ante that exceeds the chip balance is rejected as insufficientChips")
    func anteRespectsChipBalance() {
        let (game, _) = Self.newGame(startingChips: 30)
        // Need 20 to cover ante=10 + blind=10 — fine.
        #expect(game.perform(.placeAnte(amount: 10)).isSuccess)
        // Need 40 to cover ante=20 + blind=20 — fail (only 30 starting; 20 still on table = 30 available).
        let result = game.perform(.placeAnte(amount: 20))
        guard case .failure(.insufficientChips(let required, let available)) = result else {
            Issue.record("expected .insufficientChips, got \(result)")
            return
        }
        #expect(required == 40)
        #expect(available == 30)
    }

    @Test("Placing Trips deducts the trips amount")
    func tripsPlacementDeducts() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeTrips(amount: 5))
        #expect(game.tripsBet == 5)
        #expect(game.chipBalance == 4995)
    }

    @Test("Trips of zero or less is rejected as invalidBetAmount")
    func tripsMustBePositive() {
        let (game, _) = Self.newGame()
        let result = game.perform(.placeTrips(amount: 0))
        guard case .failure(.invalidBetAmount) = result else {
            Issue.record("expected .invalidBetAmount, got \(result)")
            return
        }
    }

    // MARK: - Deal

    @Test("Cannot deal without an Ante placed")
    func cannotDealWithoutAnte() {
        let (game, _) = Self.newGame()
        let result = game.perform(.deal)
        guard case .failure(.invalidBetAmount) = result else {
            Issue.record("expected .invalidBetAmount, got \(result)")
            return
        }
        #expect(game.phase == .awaitingBets)
    }

    @Test("Deal hands 2 cards to player and 2 to dealer and advances to .preFlopDecision")
    func dealAdvancesAndDistributesCards() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        let result = game.perform(.deal)
        #expect(result.isSuccess)
        #expect(game.phase == .preFlopDecision)
        #expect(game.playerHoleCards.count == 2)
        #expect(game.dealerHoleCards.count == 2)
        #expect(game.communityCards.isEmpty)
    }

    @Test("Cannot place Ante after the deal")
    func cannotPlaceAnteAfterDeal() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.placeAnte(amount: 20))
        guard case .failure(.illegalActionForPhase(_, let phase)) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
        #expect(phase == .preFlopDecision)
    }

    @Test("Cannot place Trips after the deal")
    func cannotPlaceTripsAfterDeal() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.placeTrips(amount: 5))
        guard case .failure(.illegalActionForPhase) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
    }

    // MARK: - Pre-flop decision

    @Test("Betting 4× pre-flop sets playBet to 4 × Ante and resolves the hand")
    func bet4xPreFlopResolvesHand() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.betPreFlop(multiplier: 4))
        #expect(result.isSuccess)
        #expect(game.playBet == 40)
        #expect(game.phase == .handComplete)
        #expect(game.communityCards.count == 5)
        #expect(game.lastHandResult != nil)
    }

    @Test("Betting 3× pre-flop sets playBet to 3 × Ante and resolves the hand")
    func bet3xPreFlopResolvesHand() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.betPreFlop(multiplier: 3))
        #expect(result.isSuccess)
        #expect(game.playBet == 30)
        #expect(game.phase == .handComplete)
        #expect(game.communityCards.count == 5)
        #expect(game.lastHandResult != nil)
    }

    @Test("Pre-flop multiplier other than 3 or 4 is rejected as invalidMultiplier")
    func invalidPreFlopMultiplier() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.betPreFlop(multiplier: 2))
        guard case .failure(.invalidMultiplier(let given, let allowed)) = result else {
            Issue.record("expected .invalidMultiplier, got \(result)")
            return
        }
        #expect(given == 2)
        #expect(allowed == [3, 4])
        // Phase did not advance; the player can still decide.
        #expect(game.phase == .preFlopDecision)
    }

    @Test("Pre-flop bet exceeding the chip balance is rejected")
    func preFlopBetRespectsChipBalance() {
        // Starting chips: 30. Ante 10 (deducts ante+blind = 20, leaves 10).
        // 4× pre-flop would require 40 — only 10 left.
        let (game, _) = Self.newGame(startingChips: 30)
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.betPreFlop(multiplier: 4))
        guard case .failure(.insufficientChips) = result else {
            Issue.record("expected .insufficientChips, got \(result)")
            return
        }
        #expect(game.phase == .preFlopDecision)
        #expect(game.playBet == 0)
    }

    @Test("Checking pre-flop deals the flop and advances to .postFlopDecision")
    func checkPreFlopDealsFlop() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.checkPreFlop)
        #expect(result.isSuccess)
        #expect(game.phase == .postFlopDecision)
        #expect(game.communityCards.count == 3)
        #expect(game.playBet == 0)
        #expect(game.lastHandResult == nil)
    }

    // MARK: - Post-flop decision

    @Test("Betting post-flop sets playBet to 2 × Ante and resolves the hand")
    func betPostFlopResolves() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        let result = game.perform(.betPostFlop)
        #expect(result.isSuccess)
        #expect(game.playBet == 20)
        #expect(game.phase == .handComplete)
        #expect(game.communityCards.count == 5)
        #expect(game.lastHandResult != nil)
    }

    @Test("Checking post-flop deals turn+river and advances to .postRiverDecision")
    func checkPostFlopDealsTurnAndRiver() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        let result = game.perform(.checkPostFlop)
        #expect(result.isSuccess)
        #expect(game.phase == .postRiverDecision)
        #expect(game.communityCards.count == 5)
        #expect(game.playBet == 0)
    }

    // MARK: - Post-river decision

    @Test("Betting post-river sets playBet to 1 × Ante and resolves the hand")
    func betPostRiverResolves() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        let result = game.perform(.betPostRiver)
        #expect(result.isSuccess)
        #expect(game.playBet == 10)
        #expect(game.phase == .handComplete)
        #expect(game.lastHandResult != nil)
    }

    @Test("Folding post-river forfeits Ante and Blind, leaves Play unplaced, and advances to .handComplete")
    func foldPostRiver() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        let balanceBeforeFold = game.chipBalance
        let result = game.perform(.fold)
        #expect(result.isSuccess)
        #expect(game.phase == .handComplete)
        #expect(game.playerFolded == true)
        #expect(game.playBet == 0)
        guard let summary = game.lastHandResult else {
            Issue.record("expected lastHandResult to be populated after fold")
            return
        }
        #expect(summary.anteOutcome == .lose)
        #expect(summary.blindOutcome == .lose)
        #expect(summary.anteNet == -10)
        #expect(summary.blindNet == -10)
        #expect(summary.playNet == 0)
        // No Trips placed; balance is unchanged by the fold itself
        // (the Ante/Blind chips were deducted up front and are not returned).
        #expect(game.chipBalance == balanceBeforeFold)
    }

    @Test("Folding post-river still pays the Trips side bet on a qualifying player hand")
    func foldStillResolvesTrips() {
        // Stack the deck: trick the test by running many hands until we get a
        // player Trips win? That's flaky. Instead, verify via state machine:
        // run a fold and confirm tripsOutcome reflects the actual evaluation,
        // and chipBalance moved by exactly (tripsBet + tripsNet).
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.placeTrips(amount: 5))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        let balanceBeforeFold = game.chipBalance
        _ = game.perform(.fold)
        guard let summary = game.lastHandResult else {
            Issue.record("expected lastHandResult to be populated after fold")
            return
        }
        let expectedDelta = 5 + Int(summary.tripsNet.rounded())
        #expect(game.chipBalance == balanceBeforeFold + expectedDelta)
    }

    // MARK: - Resolution updates chip balance

    @Test("Resolution updates chipBalance by the sum of (stake + net) for every wager")
    func chipBalanceMatchesResolution() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.placeTrips(amount: 5))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 4))
        guard let summary = game.lastHandResult else {
            Issue.record("expected lastHandResult after resolution")
            return
        }
        // 5000 starting; chips were deducted on placement and returned with net.
        let expected = 5000
            + Int(summary.anteNet.rounded())
            + Int(summary.blindNet.rounded())
            + Int(summary.playNet.rounded())
            + Int(summary.tripsNet.rounded())
        #expect(game.chipBalance == expected)
    }

    // MARK: - collectAndReset

    @Test("collectAndReset returns to .awaitingBets with empty hands and zero bets")
    func collectAndResetClearsHand() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.placeTrips(amount: 5))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 4))
        let balanceAfterResolution = game.chipBalance
        let result = game.perform(.collectAndReset)
        #expect(result.isSuccess)
        #expect(game.phase == .awaitingBets)
        #expect(game.anteBet == 0)
        #expect(game.blindBet == 0)
        #expect(game.tripsBet == 0)
        #expect(game.playBet == 0)
        #expect(game.playerFolded == false)
        #expect(game.playerHoleCards.isEmpty)
        #expect(game.dealerHoleCards.isEmpty)
        #expect(game.communityCards.isEmpty)
        #expect(game.lastHandResult == nil)
        // Balance carries over to the next hand untouched.
        #expect(game.chipBalance == balanceAfterResolution)
        // The deck is fresh again — 52 cards.
        #expect(game.deck.count == 52)
    }

    // MARK: - Illegal action enforcement

    @Test("Folding pre-flop is rejected as illegalActionForPhase")
    func cannotFoldPreFlop() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.fold)
        guard case .failure(.illegalActionForPhase(_, let phase)) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
        #expect(phase == .preFlopDecision)
    }

    @Test("Folding post-flop is rejected as illegalActionForPhase")
    func cannotFoldPostFlop() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        let result = game.perform(.fold)
        guard case .failure(.illegalActionForPhase(_, let phase)) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
        #expect(phase == .postFlopDecision)
    }

    @Test("checkPreFlop is illegal post-flop")
    func checkPreFlopIllegalAfterFlop() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        let result = game.perform(.checkPreFlop)
        guard case .failure(.illegalActionForPhase) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
    }

    @Test("betPostRiver is illegal at .preFlopDecision")
    func betPostRiverIllegalPreFlop() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.betPostRiver)
        guard case .failure(.illegalActionForPhase) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
    }

    @Test("collectAndReset is illegal mid-hand")
    func collectAndResetIllegalMidHand() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        let result = game.perform(.collectAndReset)
        guard case .failure(.illegalActionForPhase) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
    }

    @Test("Re-dealing after a hand completes requires collectAndReset first")
    func cannotDealAfterHandComplete() {
        let (game, _) = Self.newGame()
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 4))
        let result = game.perform(.deal)
        guard case .failure(.illegalActionForPhase(_, let phase)) = result else {
            Issue.record("expected .illegalActionForPhase, got \(result)")
            return
        }
        #expect(phase == .handComplete)
    }

    // MARK: - Persistence integration (session 5)

    @Test("totalHandsPlayed increments after each resolved hand")
    func totalHandsPlayedIncrements() {
        let store = InMemoryChipStore(chipBalance: 5_000)
        let game = GameState(chipStore: store)
        #expect(store.totalHandsPlayed == 0)

        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 4))
        #expect(store.totalHandsPlayed == 1)

        _ = game.perform(.collectAndReset)
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        _ = game.perform(.fold)
        #expect(store.totalHandsPlayed == 2)
    }

    @Test("chipBalance persists across a GameState lifecycle via the shared ChipStore")
    func chipBalancePersistsAcrossLifecycles() {
        let store = InMemoryChipStore(chipBalance: 5_000)

        // Lifecycle 1: play and discard a hand.
        do {
            let game = GameState(chipStore: store)
            _ = game.perform(.placeAnte(amount: 10))
            _ = game.perform(.deal)
            _ = game.perform(.betPreFlop(multiplier: 4))
            _ = game.perform(.collectAndReset)
        }
        let balanceAfterFirstHand = store.chipBalance

        // Lifecycle 2: a brand-new GameState backed by the same store
        // should observe the balance from the first lifecycle.
        let secondGame = GameState(chipStore: store)
        #expect(secondGame.chipBalance == balanceAfterFirstHand)
    }
}

// MARK: - Test helpers

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
