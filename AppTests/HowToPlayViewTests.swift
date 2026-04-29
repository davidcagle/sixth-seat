import Foundation
import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("HowToPlayView (Session 15a)")
struct HowToPlayViewTests {

    @Test("HowToPlayView instantiates without crashing")
    func viewInstantiates() {
        _ = HowToPlayView()
    }

    // MARK: - Paytable row counts match the Vegas paytables

    @Test("Blind paytable surfaces 6 paying rows plus a 'Push' row (7 rows total)")
    func blindRowsHaveExpectedCount() {
        // Royal flush, straight flush, four of a kind, full house, flush,
        // straight = 6 paying ranks. Plus an "All other wins -> Push" row
        // for hands below a straight.
        #expect(HowToPlayCopy.blindRows.count == 7)
    }

    @Test("Trips paytable surfaces 7 rows (no push)")
    func tripsRowsHaveExpectedCount() {
        // Royal flush, straight flush, four of a kind, full house, flush,
        // straight, three of a kind. Trips never pushes.
        #expect(HowToPlayCopy.tripsRows.count == 7)
    }

    // MARK: - Paytable values come from the engine

    @Test("Blind row payouts match UTHRules.blindPaytable verbatim")
    func blindRowsMatchEngine() {
        // The view renders rows by reading from `UTHRules.blindPaytable`.
        // For each rank present in the engine's paytable, the rendered
        // row's payout text must be the formatted form of that
        // multiplier — not a hard-coded literal in the view layer.
        let rowsByRank: [HandRank: HowToPlayCopy.PaytableRow] = HowToPlayCopy.blindRows
            .reduce(into: [:]) { acc, row in
                if let rank = row.rank { acc[rank] = row }
            }
        for (rank, multiplier) in UTHRules.blindPaytable {
            let row = try! #require(rowsByRank[rank])
            #expect(row.payout == HowToPlayCopy.formatMultiplier(multiplier))
        }
    }

    @Test("Trips row payouts match UTHRules.tripsPaytable verbatim")
    func tripsRowsMatchEngine() {
        let rowsByRank: [HandRank: HowToPlayCopy.PaytableRow] = HowToPlayCopy.tripsRows
            .reduce(into: [:]) { acc, row in
                if let rank = row.rank { acc[rank] = row }
            }
        for (rank, multiplier) in UTHRules.tripsPaytable {
            let row = try! #require(rowsByRank[rank])
            #expect(row.payout == HowToPlayCopy.formatMultiplier(multiplier))
        }
    }

    // MARK: - Specific high-stakes payouts on the felt

    @Test("Blind paytable headline rows render Vegas-correct strings")
    func blindHeadlinePayouts() {
        let rowsByRank: [HandRank: HowToPlayCopy.PaytableRow] = HowToPlayCopy.blindRows
            .reduce(into: [:]) { acc, row in
                if let rank = row.rank { acc[rank] = row }
            }

        // Royal flush 500:1, straight flush 50:1, four of a kind 10:1,
        // full house 3:1, flush 3:2, straight 1:1.
        #expect(rowsByRank[.royalFlush]?.payout == "500:1")
        #expect(rowsByRank[.straightFlush]?.payout == "50:1")
        #expect(rowsByRank[.fourOfAKind]?.payout == "10:1")
        #expect(rowsByRank[.fullHouse]?.payout == "3:1")
        #expect(rowsByRank[.flush]?.payout == "3:2")
        #expect(rowsByRank[.straight]?.payout == "1:1")
    }

    @Test("Trips paytable headline rows render Vegas-correct strings")
    func tripsHeadlinePayouts() {
        let rowsByRank: [HandRank: HowToPlayCopy.PaytableRow] = HowToPlayCopy.tripsRows
            .reduce(into: [:]) { acc, row in
                if let rank = row.rank { acc[rank] = row }
            }

        #expect(rowsByRank[.royalFlush]?.payout == "50:1")
        #expect(rowsByRank[.straightFlush]?.payout == "40:1")
        #expect(rowsByRank[.fourOfAKind]?.payout == "30:1")
        #expect(rowsByRank[.fullHouse]?.payout == "8:1")
        #expect(rowsByRank[.flush]?.payout == "6:1")
        #expect(rowsByRank[.straight]?.payout == "5:1")
        #expect(rowsByRank[.threeOfAKind]?.payout == "3:1")
    }

    // MARK: - Paytable display order

    @Test("Blind rows are sorted strongest-to-weakest (Royal Flush first, Straight last paying)")
    func blindRowsAreOrderedStrongestFirst() {
        // The first row's rank must be the strongest paying hand; the
        // last paying row must be straight, with the push row trailing.
        let firstRow = HowToPlayCopy.blindRows.first
        #expect(firstRow?.rank == .royalFlush)
        let payingRows = HowToPlayCopy.blindRows.compactMap(\.rank)
        #expect(payingRows.last == .straight)
        // Last row is the catch-all push.
        #expect(HowToPlayCopy.blindRows.last?.rank == nil)
        #expect(HowToPlayCopy.blindRows.last?.payout == "Push")
    }

    @Test("Trips rows are sorted strongest-to-weakest")
    func tripsRowsAreOrderedStrongestFirst() {
        let ranks = HowToPlayCopy.tripsRows.compactMap(\.rank)
        #expect(ranks.first == .royalFlush)
        #expect(ranks.last == .threeOfAKind)
    }

    // MARK: - Helper formatter

    @Test("Multiplier formatter renders integers as N:1 and 1.5 as 3:2")
    func multiplierFormatter() {
        #expect(HowToPlayCopy.formatMultiplier(500) == "500:1")
        #expect(HowToPlayCopy.formatMultiplier(50) == "50:1")
        #expect(HowToPlayCopy.formatMultiplier(3) == "3:1")
        #expect(HowToPlayCopy.formatMultiplier(1) == "1:1")
        #expect(HowToPlayCopy.formatMultiplier(1.5) == "3:2")
    }

    // MARK: - Rules content invariants

    @Test("Hand flow lists the canonical 9 UTH steps")
    func handFlowHasNineSteps() {
        #expect(HowToPlayCopy.handFlow.count == 9)
    }

    @Test("Pairs Plus note explicitly states 6th Seat does not offer it")
    func pairsPlusNoteIsExplicit() {
        // Apple reviewers and players both need to see this stated
        // outright — locking the substring guards against a copy edit
        // accidentally softening it.
        #expect(HowToPlayCopy.pairsPlusNote.contains("does not offer the Pairs Plus"))
    }
}
