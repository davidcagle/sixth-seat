import Testing
@testable import SixthSeat

@Suite("ChipDecomposition (Session 21 bet-zone chip visualization)")
struct ChipDecompositionTests {

    @Test("Single-chip exact matches return count = 1")
    func exactSingleChipDenominations() {
        #expect(ChipDecomposition.bestFit(for: 5)    == ChipDecomposition(denomination: 5,    count: 1))
        #expect(ChipDecomposition.bestFit(for: 25)   == ChipDecomposition(denomination: 25,   count: 1))
        #expect(ChipDecomposition.bestFit(for: 100)  == ChipDecomposition(denomination: 100,  count: 1))
        #expect(ChipDecomposition.bestFit(for: 500)  == ChipDecomposition(denomination: 500,  count: 1))
        #expect(ChipDecomposition.bestFit(for: 1000) == ChipDecomposition(denomination: 1000, count: 1))
    }

    @Test("Multiples of a denomination return that denomination with count = quotient")
    func cleanMultiples() {
        // $10 → two $5 chips
        #expect(ChipDecomposition.bestFit(for: 10) == ChipDecomposition(denomination: 5, count: 2))
        // $50 → two $25 chips
        #expect(ChipDecomposition.bestFit(for: 50) == ChipDecomposition(denomination: 25, count: 2))
        // $200 → two $100 chips
        #expect(ChipDecomposition.bestFit(for: 200) == ChipDecomposition(denomination: 100, count: 2))
    }

    @Test("Off-grid amounts approximate via the largest denomination ≤ amount")
    func offGridApproximations() {
        // $35 → one $25 chip (precise value comes from the dollar label)
        #expect(ChipDecomposition.bestFit(for: 35) == ChipDecomposition(denomination: 25, count: 1))
        // $250 → two $100 chips (50 leftover, communicated by the label)
        #expect(ChipDecomposition.bestFit(for: 250) == ChipDecomposition(denomination: 100, count: 2))
    }

    @Test("Larger amounts pick the largest available denomination")
    func picksLargestAvailableDenomination() {
        // $1,500 → one $1,000 chip (500 leftover)
        #expect(ChipDecomposition.bestFit(for: 1_500) == ChipDecomposition(denomination: 1000, count: 1))
        // $5,000 → five $1,000 chips
        #expect(ChipDecomposition.bestFit(for: 5_000) == ChipDecomposition(denomination: 1000, count: 5))
    }

    @Test("Zero amount returns nil — no chip stack should render")
    func zeroReturnsNil() {
        #expect(ChipDecomposition.bestFit(for: 0) == nil)
    }

    @Test("Negative amount returns nil (defensive floor)")
    func negativeReturnsNil() {
        #expect(ChipDecomposition.bestFit(for: -1) == nil)
        #expect(ChipDecomposition.bestFit(for: -1000) == nil)
    }

    @Test("Sub-$5 amounts return nil — below the smallest chip denomination")
    func belowSmallestDenominationReturnsNil() {
        // No way to render a stack at $1–$4 with our chip set; the
        // V1 cycles never produce these values (smallest cycle step
        // is $5), but the helper stays total by returning nil.
        #expect(ChipDecomposition.bestFit(for: 1) == nil)
        #expect(ChipDecomposition.bestFit(for: 4) == nil)
    }

    @Test("Available denominations match the V1 chip set, largest first")
    func availableDenominationsContract() {
        #expect(ChipDecomposition.availableDenominations == [1000, 500, 100, 25, 5])
    }
}
