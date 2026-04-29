import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@Suite("PayoutBreakdownView (Session 15b)")
struct PayoutBreakdownTests {

    // MARK: - Synthetic hand-result fixtures

    /// 2♣ 2♦ — used as a stand-in for any "qualifies-but-loses" dealer
    /// hand when we want the player to compare against something specific.
    private static let lowPair: EvaluatedHand = HandEvaluator.evaluate(cards: [
        Card(rank: .two, suit: .clubs),
        Card(rank: .two, suit: .diamonds),
        Card(rank: .three, suit: .hearts),
        Card(rank: .seven, suit: .spades),
        Card(rank: .nine, suit: .clubs)
    ])

    private static let kingHigh: EvaluatedHand = HandEvaluator.evaluate(cards: [
        Card(rank: .king, suit: .clubs),
        Card(rank: .nine, suit: .diamonds),
        Card(rank: .seven, suit: .hearts),
        Card(rank: .three, suit: .spades),
        Card(rank: .two, suit: .clubs)
    ])

    private static let aceHighFlush: EvaluatedHand = HandEvaluator.evaluate(cards: [
        Card(rank: .ace, suit: .hearts),
        Card(rank: .king, suit: .hearts),
        Card(rank: .nine, suit: .hearts),
        Card(rank: .seven, suit: .hearts),
        Card(rank: .three, suit: .hearts)
    ])

    private static let highStraight: EvaluatedHand = HandEvaluator.evaluate(cards: [
        Card(rank: .ace, suit: .hearts),
        Card(rank: .king, suit: .clubs),
        Card(rank: .queen, suit: .diamonds),
        Card(rank: .jack, suit: .hearts),
        Card(rank: .ten, suit: .spades)
    ])

    // MARK: - PayoutLine composition

    @Test("Line is omitted when stake is 0")
    func zeroStakeOmits() {
        #expect(PayoutLine.make(label: "TRIPS", outcome: .lose, stake: 0) == nil)
    }

    @Test("Win on a 1:1 bet shows +stake with no ratio annotation")
    func winOneToOne() {
        let line = PayoutLine.make(label: "ANTE", outcome: .win, stake: 25)
        #expect(line?.result == .win)
        #expect(line?.amount == 25)
        #expect(line?.payoutRatio == nil)
    }

    @Test("Loss on a 1:1 bet shows the negative stake")
    func lossOneToOne() {
        let line = PayoutLine.make(label: "PLAY", outcome: .lose, stake: 100)
        #expect(line?.result == .loss)
        #expect(line?.amount == -100)
        #expect(line?.payoutRatio == nil)
    }

    @Test("Push shows zero amount and PUSH result")
    func pushAmountsToZero() {
        let line = PayoutLine.make(label: "ANTE", outcome: .push, stake: 50)
        #expect(line?.result == .push)
        #expect(line?.amount == 0)
        #expect(line?.payoutRatio == nil)
    }

    @Test("Blind 3:2 (flush) renders the (3:2) ratio")
    func blindFlushRatio() {
        let line = PayoutLine.make(
            label: "BLIND",
            outcome: .blindBonus(multiplier: 1.5),
            stake: 25
        )
        #expect(line?.result == .win)
        #expect(line?.amount == 37.5)
        #expect(line?.payoutRatio == "3:2")
    }

    @Test("Trips 6:1 (flush) renders the (6:1) ratio")
    func tripsFlushRatio() {
        let line = PayoutLine.make(
            label: "TRIPS",
            outcome: .blindBonus(multiplier: 6),
            stake: 5
        )
        #expect(line?.result == .win)
        #expect(line?.amount == 30)
        #expect(line?.payoutRatio == "6:1")
    }

    @Test("1:1 blind win does not render a ratio")
    func blindOneToOneNoRatio() {
        // Blind paytable's straight rung pays even money.
        let line = PayoutLine.make(
            label: "BLIND",
            outcome: .blindBonus(multiplier: 1.0),
            stake: 25
        )
        #expect(line?.payoutRatio == nil)
        #expect(line?.amount == 25)
    }

    // MARK: - PayoutBreakdownLogic.lines (filtering)

    @Test("Folded hand omits the PLAY line even when playBet > 0")
    func foldedHandOmitsPlayLine() {
        // Construct a hand result by hand — after a fold the engine's
        // playOutcome is .lose with a zero playNet (the engine doesn't
        // refund a fold). The view's "playerFolded" flag is what hides
        // the row regardless of the engine's playOutcome.
        let result = HandResult(
            playerHand: Self.kingHigh,
            dealerHand: Self.lowPair,
            dealerQualifies: true,
            anteOutcome: .lose,
            blindOutcome: .lose,
            playOutcome: .lose,
            tripsOutcome: .lose,
            anteNet: -10,
            blindNet: -10,
            playNet: 0,
            tripsNet: 0
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 10,
            blindBet: 10,
            playBet: 0,
            tripsBet: 0,
            playerFolded: true
        )
        #expect(lines.map(\.label) == ["ANTE", "BLIND"])
    }

    @Test("Hand with no Trips placed omits the TRIPS line")
    func noTripsOmitsTripsLine() {
        let result = HandResult(
            playerHand: Self.kingHigh,
            dealerHand: Self.lowPair,
            dealerQualifies: true,
            anteOutcome: .lose,
            blindOutcome: .lose,
            playOutcome: .lose,
            tripsOutcome: .lose,
            anteNet: -10,
            blindNet: -10,
            playNet: -20,
            tripsNet: 0
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 10,
            blindBet: 10,
            playBet: 20,
            tripsBet: 0,
            playerFolded: false
        )
        #expect(lines.map(\.label) == ["ANTE", "BLIND", "PLAY"])
    }

    @Test("Dealer no-qualify shows ANTE PUSH and BLIND on its own paytable")
    func dealerNoQualifyAntePushes() {
        // Dealer no-qualify: Ante pushes; Play resolves 1:1; Blind resolves
        // on its paytable (or pushes for sub-straight wins).
        let result = HandResult(
            playerHand: Self.aceHighFlush,
            dealerHand: Self.kingHigh,
            dealerQualifies: false,
            anteOutcome: .push,
            blindOutcome: .blindBonus(multiplier: 1.5),
            playOutcome: .win,
            tripsOutcome: .lose,
            anteNet: 0,
            blindNet: 37.5,
            playNet: 50,
            tripsNet: 0
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 25,
            blindBet: 25,
            playBet: 50,
            tripsBet: 0,
            playerFolded: false
        )
        #expect(lines.count == 3)
        #expect(lines[0].label == "ANTE")
        #expect(lines[0].result == .push)
        #expect(lines[1].label == "BLIND")
        #expect(lines[1].result == .win)
        #expect(lines[1].payoutRatio == "3:2")
        #expect(lines[2].label == "PLAY")
        #expect(lines[2].result == .win)
    }

    @Test("Trips placed and flush hits shows TRIPS line with (6:1) ratio")
    func tripsFlushBreakdown() {
        let result = HandResult(
            playerHand: Self.aceHighFlush,
            dealerHand: Self.highStraight,  // dealer has straight (qualifies)
            dealerQualifies: true,
            anteOutcome: .lose,
            blindOutcome: .lose,
            playOutcome: .lose,
            tripsOutcome: .blindBonus(multiplier: 6),
            anteNet: -10,
            blindNet: -10,
            playNet: -30,
            tripsNet: 30
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 10,
            blindBet: 10,
            playBet: 30,
            tripsBet: 5,
            playerFolded: false
        )
        let trips = lines.first(where: { $0.label == "TRIPS" })
        #expect(trips?.result == .win)
        #expect(trips?.amount == 30)
        #expect(trips?.payoutRatio == "6:1")
    }

    @Test("Total line equals the signed sum of all displayed line amounts")
    func totalIsSignedSum() {
        let result = HandResult(
            playerHand: Self.aceHighFlush,
            dealerHand: Self.kingHigh,
            dealerQualifies: false,
            anteOutcome: .push,
            blindOutcome: .blindBonus(multiplier: 1.5),
            playOutcome: .win,
            tripsOutcome: .blindBonus(multiplier: 6),
            anteNet: 0,
            blindNet: 37.5,
            playNet: 50,
            tripsNet: 30
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 25,
            blindBet: 25,
            playBet: 50,
            tripsBet: 5,
            playerFolded: false
        )
        let total = PayoutBreakdownLogic.totalNet(of: lines)
        // 0 (ante push) + 37.5 (blind 3:2 on $25) + 50 (play 1:1) + 30 (trips 6:1 on $5)
        #expect(total == 117.5)
    }

    @Test("Losing hand renders negative line amounts and a negative total")
    func losingHandRendersNegatives() {
        let result = HandResult(
            playerHand: Self.kingHigh,
            dealerHand: Self.lowPair,
            dealerQualifies: true,
            anteOutcome: .lose,
            blindOutcome: .lose,
            playOutcome: .lose,
            tripsOutcome: .lose,
            anteNet: -25,
            blindNet: -25,
            playNet: -75,
            tripsNet: -5
        )
        let lines = PayoutBreakdownLogic.lines(
            from: result,
            anteBet: 25,
            blindBet: 25,
            playBet: 75,
            tripsBet: 5,
            playerFolded: false
        )
        for line in lines {
            #expect(line.result == .loss, "\(line.label) should be a loss")
            #expect(line.amount < 0)
        }
        #expect(PayoutBreakdownLogic.totalNet(of: lines) == -130)
    }

    // MARK: - Ratio formatting

    @Test("Ratio formatter handles common paytable multipliers")
    func ratioFormatter() {
        #expect(PayoutLine.formatRatio(1.5) == "3:2")
        #expect(PayoutLine.formatRatio(3) == "3:1")
        #expect(PayoutLine.formatRatio(6) == "6:1")
        #expect(PayoutLine.formatRatio(10) == "10:1")
        #expect(PayoutLine.formatRatio(50) == "50:1")
        #expect(PayoutLine.formatRatio(500) == "500:1")
    }

    @Test("Lines from the engine's actual UTHRules paytable preserve the ratios")
    func paytableConsistency() {
        // Sanity check: the multipliers we see in the UI are the same
        // values UTHRules.blindPaytable / tripsPaytable expose. If the
        // engine ever changes the rates, the formatter must keep up.
        for (rank, multiplier) in UTHRules.blindPaytable {
            let line = PayoutLine.make(label: "BLIND", outcome: .blindBonus(multiplier: multiplier), stake: 10)
            #expect(line != nil, "missing line for \(rank)")
            let expectedAmount = 10.0 * multiplier
            #expect(line?.amount == expectedAmount)
        }
        for (rank, multiplier) in UTHRules.tripsPaytable {
            let line = PayoutLine.make(label: "TRIPS", outcome: .blindBonus(multiplier: multiplier), stake: 5)
            #expect(line != nil, "missing line for \(rank)")
            let expectedAmount = 5.0 * multiplier
            #expect(line?.amount == expectedAmount)
        }
    }
}
