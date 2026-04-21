import Testing
@testable import SixthSeat

@Suite("Deck")
struct DeckTests {

    @Test("A new deck contains exactly 52 cards")
    func newDeckHas52Cards() {
        let deck = Deck()
        #expect(deck.count == 52)
    }

    @Test("All 52 cards in a new deck are unique")
    func allCardsAreUnique() {
        let deck = Deck()
        let unique = Set(deck.cards)
        #expect(unique.count == 52)
    }

    @Test("Shuffle produces varied orderings (≥95/100 unique first-5 sequences)")
    func shuffleProducesDifferentOrderings() {
        var firstFiveSequences: [String] = []
        for _ in 0..<100 {
            var deck = Deck()
            deck.shuffle()
            let key = deck.cards.prefix(5).map(\.display).joined(separator: ",")
            firstFiveSequences.append(key)
        }
        let uniqueCount = Set(firstFiveSequences).count
        #expect(
            uniqueCount >= 95,
            "Expected ≥95 unique first-5 sequences across 100 shuffles, got \(uniqueCount)"
        )
    }

    @Test("deal() returns a valid card and reduces count by 1")
    func dealReturnsCardAndDecrementsCount() {
        var deck = Deck()
        let before = deck.count
        let card = deck.deal()
        #expect(card != nil)
        #expect(deck.count == before - 1)
    }

    @Test("deal() from an empty deck returns nil without crashing")
    func dealFromEmptyDeckReturnsNil() {
        var deck = Deck()
        for _ in 0..<52 { _ = deck.deal() }
        #expect(deck.count == 0)
        #expect(deck.deal() == nil)
        #expect(deck.count == 0)
    }

    @Test("reset() restores the deck to 52 cards")
    func resetRestoresDeck() {
        var deck = Deck()
        for _ in 0..<10 { _ = deck.deal() }
        #expect(deck.count == 42)
        deck.reset()
        #expect(deck.count == 52)
        #expect(Set(deck.cards).count == 52)
    }
}
