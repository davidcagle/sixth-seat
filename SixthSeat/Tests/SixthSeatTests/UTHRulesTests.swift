import Testing
@testable import SixthSeat

@Suite("UTHRules")
struct UTHRulesTests {

    // MARK: - Card / hand helpers

    private func c(_ rank: Rank, _ suit: Suit) -> Card {
        Card(rank: rank, suit: suit)
    }

    private func eval(_ cards: Card...) -> EvaluatedHand {
        HandEvaluator.evaluate(cards: cards)
    }

    // Canonical example hands at every category. Tests pull from these so
    // each rank is built exactly one way and the intent of each test stays
    // about rules behavior, not card construction.

    private func royalFlush() -> EvaluatedHand {
        eval(c(.ace, .spades), c(.king, .spades), c(.queen, .spades),
             c(.jack, .spades), c(.ten, .spades))
    }

    private func straightFlush() -> EvaluatedHand {
        eval(c(.nine, .hearts), c(.eight, .hearts), c(.seven, .hearts),
             c(.six, .hearts), c(.five, .hearts))
    }

    private func fourOfAKind() -> EvaluatedHand {
        eval(c(.seven, .clubs), c(.seven, .diamonds), c(.seven, .hearts),
             c(.seven, .spades), c(.king, .clubs))
    }

    private func fullHouse() -> EvaluatedHand {
        eval(c(.ten, .clubs), c(.ten, .diamonds), c(.ten, .hearts),
             c(.five, .spades), c(.five, .clubs))
    }

    private func flush() -> EvaluatedHand {
        eval(c(.ace, .diamonds), c(.jack, .diamonds), c(.nine, .diamonds),
             c(.six, .diamonds), c(.three, .diamonds))
    }

    private func straight() -> EvaluatedHand {
        eval(c(.nine, .spades), c(.eight, .clubs), c(.seven, .diamonds),
             c(.six, .hearts), c(.five, .spades))
    }

    private func threeOfAKind() -> EvaluatedHand {
        eval(c(.queen, .clubs), c(.queen, .diamonds), c(.queen, .hearts),
             c(.five, .spades), c(.two, .clubs))
    }

    private func twoPair() -> EvaluatedHand {
        eval(c(.king, .clubs), c(.king, .diamonds), c(.queen, .hearts),
             c(.queen, .spades), c(.three, .clubs))
    }

    private func pair() -> EvaluatedHand {
        eval(c(.eight, .clubs), c(.eight, .diamonds), c(.king, .hearts),
             c(.five, .spades), c(.two, .clubs))
    }

    private func highCard() -> EvaluatedHand {
        eval(c(.ace, .hearts), c(.jack, .clubs), c(.nine, .diamonds),
             c(.six, .spades), c(.three, .clubs))
    }

    /// A second high-card hand the dealer can hold so tests have a
    /// non-qualifying dealer that the player still beats.
    private func lowHighCard() -> EvaluatedHand {
        eval(c(.king, .hearts), c(.ten, .clubs), c(.eight, .diamonds),
             c(.four, .spades), c(.two, .hearts))
    }

    // MARK: - DealerQualification

    @Test("Dealer qualifies on pair or better")
    func qualifiesOnPair() {
        #expect(DealerQualification.qualifies(hand: pair()))
        #expect(DealerQualification.qualifies(hand: twoPair()))
        #expect(DealerQualification.qualifies(hand: royalFlush()))
    }

    @Test("Dealer does NOT qualify on high card")
    func doesNotQualifyOnHighCard() {
        #expect(!DealerQualification.qualifies(hand: highCard()))
        #expect(!DealerQualification.qualifies(hand: lowHighCard()))
    }

    // MARK: - Ante

    @Test("Ante pushes when dealer fails to qualify, even if player wins the hand")
    func antePushOnDealerNoQualify() {
        // Player has a pair, dealer holds a high card → dealer fails to qualify.
        let player = pair()
        let dealer = highCard()
        #expect(player > dealer)
        #expect(UTHRules.resolveAnte(player: player, dealer: dealer) == .push)
    }

    @Test("Ante pushes when dealer fails to qualify, even if player loses the hand")
    func antePushOnDealerNoQualifyPlayerLoses() {
        // Two non-qualifying hands; dealer still doesn't qualify so Ante pushes.
        let player = lowHighCard() // K-high
        let dealer = highCard()    // A-high beats it
        #expect(player < dealer)
        #expect(UTHRules.resolveAnte(player: player, dealer: dealer) == .push)
    }

    @Test("Ante wins 1:1 when dealer qualifies and player wins")
    func anteWinOnDealerQualifies() {
        let player = flush()
        let dealer = pair()
        #expect(UTHRules.resolveAnte(player: player, dealer: dealer) == .win)
    }

    @Test("Ante loses when dealer qualifies and player loses")
    func anteLoseOnDealerQualifies() {
        let player = pair()
        let dealer = flush()
        #expect(UTHRules.resolveAnte(player: player, dealer: dealer) == .lose)
    }

    @Test("Ante pushes on tie when dealer qualifies")
    func antePushOnTie() {
        let p = pair()
        let d = pair()
        #expect(p == d)
        #expect(UTHRules.resolveAnte(player: p, dealer: d) == .push)
    }

    // MARK: - Play

    @Test("Play wins 1:1 against a non-qualifying dealer that the player beats")
    func playWinsAgainstNonQualifyingDealer() {
        // Critical UTH rule: Play is NOT gated by dealer qualification.
        let player = pair()
        let dealer = highCard()
        #expect(UTHRules.resolvePlay(player: player, dealer: dealer) == .win)
    }

    @Test("Play wins when player beats a qualifying dealer")
    func playWinsAgainstQualifyingDealer() {
        let player = flush()
        let dealer = pair()
        #expect(UTHRules.resolvePlay(player: player, dealer: dealer) == .win)
    }

    @Test("Play loses when dealer beats player")
    func playLoses() {
        let player = pair()
        let dealer = flush()
        #expect(UTHRules.resolvePlay(player: player, dealer: dealer) == .lose)
    }

    @Test("Play pushes on tie")
    func playPushOnTie() {
        #expect(UTHRules.resolvePlay(player: pair(), dealer: pair()) == .push)
    }

    // MARK: - Blind paytable

    @Test("Blind pays 500:1 on a winning royal flush")
    func blindRoyalFlush() {
        let outcome = UTHRules.resolveBlind(player: royalFlush(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 500))
    }

    @Test("Blind pays 50:1 on a winning straight flush")
    func blindStraightFlush() {
        let outcome = UTHRules.resolveBlind(player: straightFlush(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 50))
    }

    @Test("Blind pays 10:1 on a winning four of a kind")
    func blindFourOfAKind() {
        let outcome = UTHRules.resolveBlind(player: fourOfAKind(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 10))
    }

    @Test("Blind pays 3:1 on a winning full house")
    func blindFullHouse() {
        let outcome = UTHRules.resolveBlind(player: fullHouse(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 3))
    }

    @Test("Blind pays 3:2 on a winning flush")
    func blindFlush() {
        let outcome = UTHRules.resolveBlind(player: flush(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 1.5))
    }

    @Test("Blind pays 1:1 on a winning straight")
    func blindStraight() {
        let outcome = UTHRules.resolveBlind(player: straight(), dealer: pair())
        #expect(outcome == .blindBonus(multiplier: 1))
    }

    @Test("Blind pushes on a winning three of a kind (less than straight)")
    func blindThreeOfAKindPushes() {
        let outcome = UTHRules.resolveBlind(player: threeOfAKind(), dealer: pair())
        #expect(outcome == .push)
    }

    @Test("Blind pushes on a winning two pair (less than straight)")
    func blindTwoPairPushes() {
        let outcome = UTHRules.resolveBlind(player: twoPair(), dealer: pair())
        #expect(outcome == .push)
    }

    @Test("Blind pushes on a winning pair (less than straight)")
    func blindPairPushes() {
        // Player has pair of kings; dealer has pair of eights.
        let player = eval(c(.king, .clubs), c(.king, .diamonds),
                          c(.nine, .hearts), c(.five, .spades), c(.two, .clubs))
        let dealer = pair() // pair of 8s
        #expect(player > dealer)
        #expect(UTHRules.resolveBlind(player: player, dealer: dealer) == .push)
    }

    @Test("Blind pushes on a winning high card (less than straight)")
    func blindHighCardPushes() {
        let outcome = UTHRules.resolveBlind(player: highCard(), dealer: lowHighCard())
        #expect(outcome == .push)
    }

    @Test("Blind LOSES when player loses the hand, regardless of player's rank")
    func blindLosesOnPlayerLoss() {
        // Player has a strong-paying hand (flush) but dealer has a stronger
        // hand (full house). The Blind still LOSES — paytable doesn't apply.
        let outcome = UTHRules.resolveBlind(player: flush(), dealer: fullHouse())
        #expect(outcome == .lose)
    }

    @Test("Blind pushes on tie")
    func blindPushOnTie() {
        #expect(UTHRules.resolveBlind(player: straight(), dealer: straight()) == .push)
    }

    // MARK: - Trips paytable

    @Test("Trips pays 50:1 on a royal flush")
    func tripsRoyalFlush() {
        #expect(UTHRules.resolveTrips(player: royalFlush()) == .blindBonus(multiplier: 50))
    }

    @Test("Trips pays 40:1 on a straight flush")
    func tripsStraightFlush() {
        #expect(UTHRules.resolveTrips(player: straightFlush()) == .blindBonus(multiplier: 40))
    }

    @Test("Trips pays 30:1 on four of a kind")
    func tripsFourOfAKind() {
        #expect(UTHRules.resolveTrips(player: fourOfAKind()) == .blindBonus(multiplier: 30))
    }

    @Test("Trips pays 8:1 on a full house")
    func tripsFullHouse() {
        #expect(UTHRules.resolveTrips(player: fullHouse()) == .blindBonus(multiplier: 8))
    }

    @Test("Trips pays 6:1 on a flush")
    func tripsFlush() {
        #expect(UTHRules.resolveTrips(player: flush()) == .blindBonus(multiplier: 6))
    }

    @Test("Trips pays 5:1 on a straight")
    func tripsStraight() {
        #expect(UTHRules.resolveTrips(player: straight()) == .blindBonus(multiplier: 5))
    }

    @Test("Trips pays 3:1 on three of a kind")
    func tripsThreeOfAKind() {
        #expect(UTHRules.resolveTrips(player: threeOfAKind()) == .blindBonus(multiplier: 3))
    }

    @Test("Trips loses on two pair")
    func tripsTwoPairLoses() {
        #expect(UTHRules.resolveTrips(player: twoPair()) == .lose)
    }

    @Test("Trips loses on a single pair")
    func tripsPairLoses() {
        #expect(UTHRules.resolveTrips(player: pair()) == .lose)
    }

    @Test("Trips loses on high card")
    func tripsHighCardLoses() {
        #expect(UTHRules.resolveTrips(player: highCard()) == .lose)
    }

    // MARK: - Trips independence

    @Test("Trips pays even when the dealer fails to qualify")
    func tripsIndependentOfDealerQualification() {
        // Dealer is a high card (does not qualify). Trips still pays 5:1 on
        // the player's straight — Trips never cares about the dealer.
        let result = BetResolution.resolve(
            playerHand: straight(),
            dealerHand: highCard(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(!result.dealerQualifies)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 5))
        #expect(result.tripsNet == 5)
    }

    @Test("Trips pays even when the player loses the main hand")
    func tripsIndependentOfMainOutcome() {
        // Player has a flush (Trips pays 6:1). Dealer has a straight flush
        // and wins everything else. Trips should still pay.
        let result = BetResolution.resolve(
            playerHand: flush(),
            dealerHand: straightFlush(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(result.anteOutcome == .lose)
        #expect(result.playOutcome == .lose)
        #expect(result.blindOutcome == .lose)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 6))
        #expect(result.tripsNet == 6)
    }

    // MARK: - HandResult / BetResolution end-to-end

    @Test("Dealer fails to qualify: Ante pushes, Play wins 1:1, Blind pushes (player has trips)")
    func endToEndDealerNoQualifyPlayerWins() {
        let result = BetResolution.resolve(
            playerHand: threeOfAKind(),
            dealerHand: highCard(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(!result.dealerQualifies)
        #expect(result.anteOutcome == .push)
        #expect(result.anteNet == 0)
        #expect(result.playOutcome == .win)
        #expect(result.playNet == 2)
        #expect(result.blindOutcome == .push) // trips < straight ⇒ push
        #expect(result.blindNet == 0)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 3))
        #expect(result.tripsNet == 3)
        #expect(result.totalNet == 5)
    }

    @Test("Dealer qualifies and player wins with a flush: Ante 1:1, Play 1:1, Blind 3:2")
    func endToEndDealerQualifiesPlayerWins() {
        let result = BetResolution.resolve(
            playerHand: flush(),
            dealerHand: pair(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(result.dealerQualifies)
        #expect(result.anteOutcome == .win)
        #expect(result.anteNet == 1)
        #expect(result.playOutcome == .win)
        #expect(result.playNet == 2)
        #expect(result.blindOutcome == .blindBonus(multiplier: 1.5))
        #expect(result.blindNet == 1.5)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 6))
        #expect(result.tripsNet == 6)
        #expect(result.totalNet == 10.5)
    }

    @Test("Dealer qualifies and player loses: Ante lose, Play lose, Blind lose, Trips lose")
    func endToEndDealerQualifiesPlayerLoses() {
        let result = BetResolution.resolve(
            playerHand: pair(),
            dealerHand: flush(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(result.dealerQualifies)
        #expect(result.anteOutcome == .lose)
        #expect(result.anteNet == -1)
        #expect(result.playOutcome == .lose)
        #expect(result.playNet == -2)
        #expect(result.blindOutcome == .lose)
        #expect(result.blindNet == -1)
        #expect(result.tripsOutcome == .lose)
        #expect(result.tripsNet == -1)
        #expect(result.totalNet == -5)
    }

    @Test("Tie: every main bet pushes")
    func endToEndTie() {
        // Same straight on both sides — equal rank and equal tiebreakers.
        let result = BetResolution.resolve(
            playerHand: straight(),
            dealerHand: straight(),
            anteBet: 1, blindBet: 1, playBet: 2, tripsBet: 1
        )
        #expect(result.anteOutcome == .push)
        #expect(result.blindOutcome == .push)
        #expect(result.playOutcome == .push)
        #expect(result.anteNet == 0)
        #expect(result.blindNet == 0)
        #expect(result.playNet == 0)
        // Trips fires per its own paytable regardless of the tie.
        #expect(result.tripsOutcome == .blindBonus(multiplier: 5))
    }

    @Test("Bet amounts of zero produce zero net regardless of outcome")
    func zeroBetsProduceZeroNet() {
        let result = BetResolution.resolve(
            playerHand: royalFlush(),
            dealerHand: pair(),
            anteBet: 0, blindBet: 0, playBet: 0, tripsBet: 0
        )
        #expect(result.anteOutcome == .win)
        #expect(result.blindOutcome == .blindBonus(multiplier: 500))
        #expect(result.playOutcome == .win)
        #expect(result.tripsOutcome == .blindBonus(multiplier: 50))
        #expect(result.totalNet == 0)
    }
}
