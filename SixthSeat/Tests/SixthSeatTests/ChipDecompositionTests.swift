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

    @Test("Off-grid amounts fall back to the largest cleanly-dividing denomination")
    func offGridFallsBackToCleanDivisor() {
        // $35 → seven $5 chips (25 doesn't divide 35; falls back to 5)
        #expect(ChipDecomposition.bestFit(for: 35) == ChipDecomposition(denomination: 5, count: 7))
        // $250 → ten $25 chips (100 doesn't divide 250; falls back to 25)
        #expect(ChipDecomposition.bestFit(for: 250) == ChipDecomposition(denomination: 25, count: 10))
    }

    @Test("Larger amounts pick the largest cleanly-dividing denomination")
    func picksLargestCleanDivisor() {
        // $1,500 → three $500 chips (1000 doesn't divide 1500; 500 does)
        #expect(ChipDecomposition.bestFit(for: 1_500) == ChipDecomposition(denomination: 500, count: 3))
        // $5,000 → five $1,000 chips (1000 divides cleanly)
        #expect(ChipDecomposition.bestFit(for: 5_000) == ChipDecomposition(denomination: 1000, count: 5))
    }

    @Test("Common bet amounts produce visually distinct multi-chip stacks (Session 22)")
    func multiChipDecompositionsAreVisuallyDistinct() {
        // The point of Session 22's algorithm change: $25 and $50 must
        // not render identically, and $75 picks $25 over a fallback to $5.
        #expect(ChipDecomposition.bestFit(for: 50)  == ChipDecomposition(denomination: 25,  count: 2))
        #expect(ChipDecomposition.bestFit(for: 75)  == ChipDecomposition(denomination: 25,  count: 3))
        #expect(ChipDecomposition.bestFit(for: 125) == ChipDecomposition(denomination: 25,  count: 5))
        #expect(ChipDecomposition.bestFit(for: 300) == ChipDecomposition(denomination: 100, count: 3))
        #expect(ChipDecomposition.bestFit(for: 600) == ChipDecomposition(denomination: 100, count: 6))
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
