import Testing
@testable import SixthSeat

@Suite("ChipDecomposition (Session 25 greedy multi-denomination decomposition)")
struct ChipDecompositionTests {

    @Test("Zero amount returns an empty array — no chip stack should render")
    func zeroReturnsEmpty() {
        #expect(ChipDecomposition.decompose(amount: 0) == [])
    }

    @Test("Negative amounts return an empty array (defensive floor)")
    func negativeReturnsEmpty() {
        #expect(ChipDecomposition.decompose(amount: -1) == [])
        #expect(ChipDecomposition.decompose(amount: -1000) == [])
    }

    @Test("Single-chip exact matches return one chunk with count = 1")
    func exactSingleChipDenominations() {
        #expect(ChipDecomposition.decompose(amount: 5)    == [ChipChunk(denomination: 5,    count: 1)])
        #expect(ChipDecomposition.decompose(amount: 25)   == [ChipChunk(denomination: 25,   count: 1)])
        #expect(ChipDecomposition.decompose(amount: 100)  == [ChipChunk(denomination: 100,  count: 1)])
        #expect(ChipDecomposition.decompose(amount: 500)  == [ChipChunk(denomination: 500,  count: 1)])
        #expect(ChipDecomposition.decompose(amount: 1000) == [ChipChunk(denomination: 1000, count: 1)])
    }

    @Test("Multiples of a single denomination return one chunk with count = quotient")
    func cleanMultiplesProduceSingleChunk() {
        // $10 → two $5 chips
        #expect(ChipDecomposition.decompose(amount: 10) == [ChipChunk(denomination: 5, count: 2)])
        // $15 → three $5 chips
        #expect(ChipDecomposition.decompose(amount: 15) == [ChipChunk(denomination: 5, count: 3)])
        // $50 → two $25 chips
        #expect(ChipDecomposition.decompose(amount: 50) == [ChipChunk(denomination: 25, count: 2)])
        // $75 → three $25 chips
        #expect(ChipDecomposition.decompose(amount: 75) == [ChipChunk(denomination: 25, count: 3)])
        // $300 → three $100 chips
        #expect(ChipDecomposition.decompose(amount: 300) == [ChipChunk(denomination: 100, count: 3)])
    }

    @Test("Mixed-denomination bets return multiple chunks, largest first")
    func mixedBetsProduceMultipleChunks() {
        // $30 → one $25 + one $5
        #expect(ChipDecomposition.decompose(amount: 30) == [
            ChipChunk(denomination: 25, count: 1),
            ChipChunk(denomination: 5,  count: 1),
        ])
        // $125 → one $100 + one $25
        #expect(ChipDecomposition.decompose(amount: 125) == [
            ChipChunk(denomination: 100, count: 1),
            ChipChunk(denomination: 25,  count: 1),
        ])
        // $1235 → one $1000 + two $100 + one $25 + two $5
        #expect(ChipDecomposition.decompose(amount: 1235) == [
            ChipChunk(denomination: 1000, count: 1),
            ChipChunk(denomination: 100,  count: 2),
            ChipChunk(denomination: 25,   count: 1),
            ChipChunk(denomination: 5,    count: 2),
        ])
    }

    @Test("Chunk ordering is always largest denomination first")
    func chunkOrderingIsAlwaysLargestFirst() {
        // Walk a spread of amounts and assert the denomination sequence
        // is strictly decreasing — the invariant the view depends on to
        // render the largest chip at the bottom of the stack.
        let amounts = [10, 30, 75, 125, 300, 500, 750, 1235, 4000]
        for amount in amounts {
            let chunks = ChipDecomposition.decompose(amount: amount)
            let denoms = chunks.map(\.denomination)
            #expect(
                denoms == denoms.sorted(by: >),
                "amount \(amount) chunk order \(denoms) is not strictly decreasing"
            )
        }
    }

    @Test("Chunk counts are always positive — no zero-count chunks in the output")
    func chunkCountsAreAlwaysPositive() {
        let amounts = [5, 30, 100, 125, 750, 1000, 1235, 4000]
        for amount in amounts {
            for chunk in ChipDecomposition.decompose(amount: amount) {
                #expect(chunk.count > 0, "amount \(amount) produced a zero-count chunk")
            }
        }
    }

    @Test("Sum of chunks equals the input amount (correctness invariant)")
    func sumOfChunksEqualsInputAmount() {
        let amounts = [5, 10, 15, 25, 30, 50, 75, 100, 125, 200, 250, 300, 500,
                       750, 1000, 1235, 1500, 2000, 3000, 4000]
        for amount in amounts {
            let total = ChipDecomposition.decompose(amount: amount)
                .reduce(0) { $0 + $1.denomination * $1.count }
            #expect(total == amount, "amount \(amount) decomposed to total \(total)")
        }
    }

    @Test("Available denominations match the V1 chip set, largest first")
    func availableDenominationsContract() {
        #expect(ChipDecomposition.availableDenominations == [1000, 500, 100, 25, 5])
    }
}
