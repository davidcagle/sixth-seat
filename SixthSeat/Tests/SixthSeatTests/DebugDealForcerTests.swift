#if DEBUG

import Testing
@testable import SixthSeat

/// Engine-level coverage for the Session 18c debug-deal affordance.
/// Asserts (a) `Deck(forcedDealOrder:)` pops cards in the listed order,
/// (b) `GameState.setForcedDeck` swaps the deck so the next `deal()`
/// pulls from the forced sequence, and (c) each preset scenario in
/// `DebugScenario.dealOrder` produces the documented outcome through
/// the real engine (no parallel evaluator).
@Suite("DebugDealForcer (DEBUG-only)")
struct DebugDealForcerTests {

    // MARK: - Deck(forcedDealOrder:)

    @Test("forcedDealOrder deals cards in the listed order")
    func forcedDealOrderProducesListedOrder() {
        let cards: [Card] = [
            Card(rank: .ace,   suit: .spades),
            Card(rank: .king,  suit: .hearts),
            Card(rank: .queen, suit: .diamonds),
        ]
        var deck = Deck(forcedDealOrder: cards)
        #expect(deck.deal() == cards[0])
        #expect(deck.deal() == cards[1])
        #expect(deck.deal() == cards[2])
        #expect(deck.deal() == nil)
    }

    // MARK: - GameState.setForcedDeck

    @Test("setForcedDeck causes deal() to pull from the forced sequence")
    func setForcedDeckOverridesNextDeal() {
        let game = GameState(chipStore: InMemoryChipStore(chipBalance: 1_000))
        let cards = DebugScenario.playerFlushOnRiver.dealOrder
        game.setForcedDeck(Deck(forcedDealOrder: cards))
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)

        #expect(game.playerHoleCards == Array(cards[0..<2]))
        #expect(game.dealerHoleCards == Array(cards[2..<4]))
        #expect(game.communityCards  == Array(cards[4..<9]))
    }

    // MARK: - Scenario outcomes

    @Test("dealerDoesNotQualify produces a non-qualifying dealer hand")
    func dealerDoesNotQualifyScenarioProducesExpectedOutcome() {
        let result = playScenarioStraightToShowdown(.dealerDoesNotQualify)
        #expect(result.dealerQualifies == false)
        #expect(result.dealerHand.rank == .highCard)
        #expect(result.anteOutcome == .push) // ante pushes when dealer fails to qualify
    }

    @Test("playerFlushOnRiver produces a player flush against a dealer pair")
    func playerFlushOnRiverScenarioProducesExpectedOutcome() {
        let result = playScenarioStraightToShowdown(.playerFlushOnRiver)
        #expect(result.playerHand.rank == .flush)
        #expect(result.dealerHand.rank == .pair)
        #expect(result.dealerQualifies == true)
        #expect(result.anteOutcome == .win)
    }

    @Test("push scenario produces identical straights and a main-bet push")
    func pushScenarioProducesExpectedOutcome() {
        let result = playScenarioStraightToShowdown(.push)
        #expect(result.playerHand.rank == .straight)
        #expect(result.dealerHand.rank == .straight)
        #expect(result.anteOutcome == .push)
        #expect(result.playOutcome == .push)
    }

    /// Session 32 regression: when the dealer fails to qualify AND the
    /// player wins with a hand below the Blind paytable floor (pair vs
    /// dealer high-card), each zone must settle independently:
    ///   - Ante  pushes (dealer no-qualify gate)
    ///   - Blind pushes (pair < straight)
    ///   - Play  wins 1:1
    ///   - Trips unbet → net 0
    /// Asserts the four per-zone nets separately so a wrong Ante cannot
    /// hide behind a coincidentally-correct total.
    @Test("dealer no-qualify vs player pair: each zone settles correctly")
    func dealerNoQualifyVsPlayerPairSettlesPerZone() {
        let game = GameState(chipStore: InMemoryChipStore(chipBalance: 1_000))
        game.setForcedDeck(Deck(forcedDealOrder: DebugScenario.dealerNoQualifyPlayerPair.dealOrder))

        // Ante $10 (Blind auto-matches), then 3× pre-flop raise → Play $30.
        // Mirrors the on-device hand: Ante 10, Blind 10, Play 30, Trips 0.
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 3))

        guard let result = game.lastHandResult else {
            Issue.record("Scenario did not produce a HandResult")
            return
        }

        #expect(result.playerHand.rank == .pair)
        #expect(result.dealerHand.rank == .highCard)
        #expect(result.dealerQualifies == false)

        #expect(result.anteOutcome  == .push)
        #expect(result.blindOutcome == .push)
        #expect(result.playOutcome  == .win)
        #expect(result.tripsOutcome == .lose) // pair is below trips floor

        #expect(result.anteNet  == 0)
        #expect(result.blindNet == 0)
        #expect(result.playNet  == 30)
        #expect(result.tripsNet == 0) // unbet
        #expect(result.totalNet == 30)
    }

    /// Session 34 regression: when player and dealer both play the same
    /// board straight (a true tie on a qualifying-dealer hand) with a
    /// Trips bet placed, each zone must settle independently. Pins three
    /// rules in one assertion sweep:
    ///
    ///   - Ante  pushes on a tie (NOT via dealer-no-qualify — dealer
    ///     qualifies on a straight; this is a pure heads-up tie).
    ///   - Play  pushes on a tie.
    ///   - Blind pushes on a tie EVEN WHEN the player holds a straight.
    ///     The Blind requires the player to *beat* the dealer; tying is
    ///     not winning. This is the regression-of-interest — the rule
    ///     is also pinned synthetically by `Blind pushes on tie` in
    ///     `UTHRulesTests`, but here it is exercised end-to-end through
    ///     `BetResolution.resolve` + the real 9-card deal flow.
    ///   - Trips pays per its paytable (5:1 on a straight) independent
    ///     of the dealer — the only side bet that does so.
    ///
    /// Asserts the four per-zone nets separately so a wrong zone cannot
    /// hide behind a coincidentally-correct total (same per-zone
    /// discipline as Session 32's dealer-no-qualify regression).
    @Test("board-straight push with Trips: each zone settles correctly")
    func boardStraightPushWithTripsSettlesPerZone() {
        let game = GameState(chipStore: InMemoryChipStore(chipBalance: 2_000))
        game.setForcedDeck(Deck(forcedDealOrder: DebugScenario.boardStraightPushWithTrips.dealOrder))

        // Mirrors the on-device hand: Ante 100, Blind auto-matches 100,
        // Trips 100, then 4× pre-flop raise → Play 400.
        _ = game.perform(.placeAnte(amount: 100))
        _ = game.perform(.placeTrips(amount: 100))
        _ = game.perform(.deal)
        _ = game.perform(.betPreFlop(multiplier: 4))

        guard let result = game.lastHandResult else {
            Issue.record("Scenario did not produce a HandResult")
            return
        }

        #expect(result.playerHand.rank == .straight)
        #expect(result.dealerHand.rank == .straight)
        #expect(result.dealerQualifies == true) // straight » pair-or-better

        #expect(result.anteOutcome  == .push)
        #expect(result.blindOutcome == .push)
        #expect(result.playOutcome  == .push)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 5))

        #expect(result.anteNet  == 0)
        #expect(result.blindNet == 0)
        #expect(result.playNet  == 0)
        #expect(result.tripsNet == 500) // straight pays 5:1 on $100 Trips
        #expect(result.totalNet == 500)
    }

    // MARK: - Helpers

    /// Runs the chosen scenario through a fresh `GameState`, checking
    /// the river without folding, so the engine reaches `.handComplete`
    /// with a populated `lastHandResult`.
    private func playScenarioStraightToShowdown(_ scenario: DebugScenario) -> HandResult {
        let game = GameState(chipStore: InMemoryChipStore(chipBalance: 1_000))
        game.setForcedDeck(Deck(forcedDealOrder: scenario.dealOrder))
        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        _ = game.perform(.betPostRiver)
        guard let result = game.lastHandResult else {
            Issue.record("Scenario \(scenario) did not produce a HandResult")
            return HandResult(
                playerHand: EvaluatedHand(rank: .highCard, cards: [], tiebreakers: []),
                dealerHand: EvaluatedHand(rank: .highCard, cards: [], tiebreakers: []),
                dealerQualifies: false,
                anteOutcome: .push, blindOutcome: .push, playOutcome: .push, tripsOutcome: .lose,
                anteNet: 0, blindNet: 0, playNet: 0, tripsNet: 0
            )
        }
        return result
    }
}

#endif
