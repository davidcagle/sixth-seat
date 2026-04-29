import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@Suite("HandResultHeadline (Session 15c)")
struct HandResultHeadlineTests {

    // MARK: - Tone

    @Test("Net positive total renders as a win (green)")
    func positiveIsWin() {
        #expect(HandResultHeadline.tone(for: 25) == .win)
        #expect(HandResultHeadline.tone(for: 1) == .win)
        // 0.5 rounds away from zero to 1, so it tips into .win — the
        // tone follows the rounded display so text and color never
        // disagree on the boundary.
        #expect(HandResultHeadline.tone(for: 0.5) == .win)
        #expect(HandResultHeadline.tone(for: 117.5) == .win)
    }

    @Test("Net negative total renders as a loss (red)")
    func negativeIsLoss() {
        #expect(HandResultHeadline.tone(for: -25) == .loss)
        #expect(HandResultHeadline.tone(for: -1) == .loss)
        #expect(HandResultHeadline.tone(for: -130) == .loss)
    }

    @Test("Net zero total renders as neutral (default text color)")
    func zeroIsNeutral() {
        #expect(HandResultHeadline.tone(for: 0) == .neutral)
        // Sub-dollar rounds to zero — also reads as neutral so the
        // text and tone never disagree on the boundary.
        #expect(HandResultHeadline.tone(for: 0.4) == .neutral)
        #expect(HandResultHeadline.tone(for: -0.4) == .neutral)
    }

    // MARK: - Text

    @Test("Positive text is +$N, negative is -$N, zero is Push")
    func textFormatting() {
        #expect(HandResultHeadline.text(for: 25) == "+$25")
        #expect(HandResultHeadline.text(for: 117.5) == "+$118")  // rounds half-away-from-zero
        #expect(HandResultHeadline.text(for: -130) == "-$130")
        #expect(HandResultHeadline.text(for: 0) == "Push")
        #expect(HandResultHeadline.text(for: 0.4) == "Push")
    }

    // MARK: - Engine integration

    @Test("Net total equals sum of all BetResolution components (Ante + Blind + Play + Trips, signed)")
    func netEqualsSumOfComponents() {
        // Mixed result: ante push (dealer no-qualify), blind 3:2 flush,
        // play 1:1 win, trips 6:1 flush — the same fixture used by the
        // 15b breakdown tests so the totals stay aligned with the
        // engine's `totalNet` after the revert.
        let player: EvaluatedHand = HandEvaluator.evaluate(cards: [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts),
            Card(rank: .nine, suit: .hearts),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .three, suit: .hearts)
        ])
        let dealer: EvaluatedHand = HandEvaluator.evaluate(cards: [
            Card(rank: .king, suit: .clubs),
            Card(rank: .nine, suit: .diamonds),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .three, suit: .spades),
            Card(rank: .two, suit: .clubs)
        ])
        let result = HandResult(
            playerHand: player,
            dealerHand: dealer,
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
        // 0 + 37.5 + 50 + 30 = 117.5
        #expect(result.totalNet == 117.5)
        #expect(result.totalNet == result.anteNet + result.blindNet + result.playNet + result.tripsNet)
        #expect(HandResultHeadline.tone(for: result.totalNet) == .win)
        #expect(HandResultHeadline.text(for: result.totalNet) == "+$118")
    }
}
