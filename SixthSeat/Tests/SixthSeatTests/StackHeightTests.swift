import Testing
@testable import SixthSeat

@Suite("StackHeight")
struct StackHeightTests {

    @Test("Exact-match counts return the matching variant")
    func exactMatches() {
        #expect(StackHeight.bestFit(for: 1) == .h1)
        #expect(StackHeight.bestFit(for: 3) == .h3)
        #expect(StackHeight.bestFit(for: 5) == .h5)
        #expect(StackHeight.bestFit(for: 10) == .h10)
        #expect(StackHeight.bestFit(for: 20) == .h20)
    }

    @Test("Off-grid counts round down to the nearest variant")
    func roundsDown() {
        #expect(StackHeight.bestFit(for: 2) == .h1)
        #expect(StackHeight.bestFit(for: 4) == .h3)
        #expect(StackHeight.bestFit(for: 7) == .h5)
        #expect(StackHeight.bestFit(for: 9) == .h5)
        #expect(StackHeight.bestFit(for: 11) == .h10)
        #expect(StackHeight.bestFit(for: 15) == .h10)
        #expect(StackHeight.bestFit(for: 19) == .h10)
    }

    @Test("Counts above the largest variant clamp to h20")
    func clampsAtMax() {
        #expect(StackHeight.bestFit(for: 21) == .h20)
        #expect(StackHeight.bestFit(for: 100) == .h20)
        #expect(StackHeight.bestFit(for: 9_999) == .h20)
    }

    @Test("Sub-1 counts clamp to h1 (defensive floor)")
    func clampsAtMin() {
        #expect(StackHeight.bestFit(for: 0) == .h1)
        #expect(StackHeight.bestFit(for: -5) == .h1)
    }

    @Test("Raw values match designer-shipped variants")
    func rawValuesMatchDesignerVariants() {
        #expect(StackHeight.h1.rawValue == 1)
        #expect(StackHeight.h3.rawValue == 3)
        #expect(StackHeight.h5.rawValue == 5)
        #expect(StackHeight.h10.rawValue == 10)
        #expect(StackHeight.h20.rawValue == 20)
        #expect(StackHeight.allCases.count == 5)
    }
}
