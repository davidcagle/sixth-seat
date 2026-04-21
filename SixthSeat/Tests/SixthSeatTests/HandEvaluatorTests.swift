import Testing
@testable import SixthSeat

@Suite("HandEvaluator")
struct HandEvaluatorTests {

    private func c(_ rank: Rank, _ suit: Suit) -> Card {
        Card(rank: rank, suit: suit)
    }

    // MARK: - Category detection

    @Test("Royal flush: A-K-Q-J-10 of one suit")
    func royalFlush() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .spades), c(.king, .spades), c(.queen, .spades),
            c(.jack, .spades), c(.ten, .spades)
        ])
        #expect(hand.rank == .royalFlush)
    }

    @Test("Straight flush (9-high)")
    func straightFlush() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.nine, .hearts), c(.eight, .hearts), c(.seven, .hearts),
            c(.six, .hearts), c(.five, .hearts)
        ])
        #expect(hand.rank == .straightFlush)
        #expect(hand.tiebreakers == [9])
    }

    @Test("Wheel straight flush: A-2-3-4-5 same suit, ace is LOW")
    func wheelStraightFlush() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .clubs), c(.two, .clubs), c(.three, .clubs),
            c(.four, .clubs), c(.five, .clubs)
        ])
        #expect(hand.rank == .straightFlush)
        #expect(hand.tiebreakers == [5])
    }

    @Test("Four of a kind with correct kicker")
    func fourOfAKind() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.seven, .clubs), c(.seven, .diamonds), c(.seven, .hearts),
            c(.seven, .spades), c(.king, .clubs)
        ])
        #expect(hand.rank == .fourOfAKind)
        #expect(hand.tiebreakers == [7, 13])
    }

    @Test("Full house: trip rank then pair rank")
    func fullHouse() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ten, .clubs), c(.ten, .diamonds), c(.ten, .hearts),
            c(.five, .spades), c(.five, .clubs)
        ])
        #expect(hand.rank == .fullHouse)
        #expect(hand.tiebreakers == [10, 5])
    }

    @Test("Full house tiebreakers: aces-full beats kings-full")
    func fullHouseTiebreaker() {
        let acesFull = HandEvaluator.evaluate(cards: [
            c(.ace, .clubs), c(.ace, .diamonds), c(.ace, .hearts),
            c(.two, .spades), c(.two, .clubs)
        ])
        let kingsFull = HandEvaluator.evaluate(cards: [
            c(.king, .clubs), c(.king, .diamonds), c(.king, .hearts),
            c(.queen, .spades), c(.queen, .clubs)
        ])
        #expect(acesFull > kingsFull)
    }

    @Test("Flush (non-consecutive) with 5 high-card tiebreakers")
    func flush() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .diamonds), c(.jack, .diamonds), c(.nine, .diamonds),
            c(.six, .diamonds), c(.three, .diamonds)
        ])
        #expect(hand.rank == .flush)
        #expect(hand.tiebreakers == [14, 11, 9, 6, 3])
    }

    @Test("Broadway straight (10-J-Q-K-A) — ace is HIGH")
    func broadwayStraight() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ten, .clubs), c(.jack, .diamonds), c(.queen, .hearts),
            c(.king, .spades), c(.ace, .clubs)
        ])
        #expect(hand.rank == .straight)
        #expect(hand.tiebreakers == [14])
    }

    @Test("Wheel straight (A-2-3-4-5) — ace is LOW, high card is 5")
    func wheelStraight() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .clubs), c(.two, .diamonds), c(.three, .hearts),
            c(.four, .spades), c(.five, .clubs)
        ])
        #expect(hand.rank == .straight)
        #expect(hand.tiebreakers == [5])
    }

    @Test("Three of a kind with two kickers")
    func threeOfAKind() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.jack, .clubs), c(.jack, .diamonds), c(.jack, .hearts),
            c(.nine, .spades), c(.four, .clubs)
        ])
        #expect(hand.rank == .threeOfAKind)
        #expect(hand.tiebreakers == [11, 9, 4])
    }

    @Test("Two pair with correct kicker")
    func twoPair() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.king, .clubs), c(.king, .diamonds), c(.seven, .hearts),
            c(.seven, .spades), c(.three, .clubs)
        ])
        #expect(hand.rank == .twoPair)
        #expect(hand.tiebreakers == [13, 7, 3])
    }

    @Test("One pair with three kickers in descending order")
    func pair() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.nine, .clubs), c(.nine, .diamonds), c(.ace, .hearts),
            c(.queen, .spades), c(.four, .clubs)
        ])
        #expect(hand.rank == .pair)
        #expect(hand.tiebreakers == [9, 14, 12, 4])
    }

    @Test("High card: all five ranks as tiebreakers")
    func highCard() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .clubs), c(.jack, .diamonds), c(.nine, .hearts),
            c(.six, .spades), c(.three, .clubs)
        ])
        #expect(hand.rank == .highCard)
        #expect(hand.tiebreakers == [14, 11, 9, 6, 3])
    }

    // MARK: - 7-card evaluation

    @Test("7 cards: royal flush is selected from noise")
    func sevenCardRoyalFlush() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .spades), c(.king, .spades), c(.queen, .spades),
            c(.jack, .spades), c(.ten, .spades),
            c(.two, .hearts), c(.three, .diamonds)
        ])
        #expect(hand.rank == .royalFlush)
    }

    @Test("7 cards: best full house is picked (aces over kings)")
    func sevenCardFullHouse() {
        let hand = HandEvaluator.evaluate(cards: [
            c(.ace, .clubs), c(.ace, .diamonds), c(.ace, .hearts),
            c(.king, .spades), c(.king, .clubs),
            c(.five, .diamonds), c(.two, .hearts)
        ])
        #expect(hand.rank == .fullHouse)
        #expect(hand.tiebreakers == [14, 13])
    }

    @Test("6 cards: best 5-card straight is chosen")
    func sixCardStraight() {
        // 2,3,4,5,6,7 of mixed suits — best is 7-high straight.
        let hand = HandEvaluator.evaluate(cards: [
            c(.two, .clubs), c(.three, .diamonds), c(.four, .hearts),
            c(.five, .spades), c(.six, .clubs), c(.seven, .diamonds)
        ])
        #expect(hand.rank == .straight)
        #expect(hand.tiebreakers == [7])
    }

    // MARK: - Comparison

    @Test("Higher category beats lower category (flush > straight)")
    func categoryComparison() {
        let flush = HandEvaluator.evaluate(cards: [
            c(.ace, .diamonds), c(.jack, .diamonds), c(.nine, .diamonds),
            c(.six, .diamonds), c(.three, .diamonds)
        ])
        let straight = HandEvaluator.evaluate(cards: [
            c(.ten, .clubs), c(.jack, .diamonds), c(.queen, .hearts),
            c(.king, .spades), c(.ace, .clubs)
        ])
        #expect(flush > straight)
    }

    @Test("Same category: higher tiebreakers win (ace-high flush > king-high flush)")
    func tiebreakerComparison() {
        let aceHighFlush = HandEvaluator.evaluate(cards: [
            c(.ace, .diamonds), c(.jack, .diamonds), c(.nine, .diamonds),
            c(.six, .diamonds), c(.three, .diamonds)
        ])
        let kingHighFlush = HandEvaluator.evaluate(cards: [
            c(.king, .hearts), c(.jack, .hearts), c(.nine, .hearts),
            c(.six, .hearts), c(.three, .hearts)
        ])
        #expect(aceHighFlush > kingHighFlush)
    }

    @Test("Identical hand values are equal regardless of suit composition")
    func equalityOfIdenticalValues() {
        let a = HandEvaluator.evaluate(cards: [
            c(.ten, .clubs), c(.jack, .diamonds), c(.queen, .hearts),
            c(.king, .spades), c(.ace, .clubs)
        ])
        let b = HandEvaluator.evaluate(cards: [
            c(.ten, .diamonds), c(.jack, .hearts), c(.queen, .clubs),
            c(.king, .hearts), c(.ace, .diamonds)
        ])
        #expect(a == b)
    }
}
