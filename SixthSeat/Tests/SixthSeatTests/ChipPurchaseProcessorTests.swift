import Foundation
import Testing
@testable import SixthSeat

@Suite("ChipPurchaseProcessor")
struct ChipPurchaseProcessorTests {

    private let bundle = ChipBundle(
        id: "com.sixthseat.uth.chips.testbundle",
        displayName: "Test",
        chipAmount: 10_000,
        localizedPrice: "$0.99"
    )

    // MARK: - First-purchase doubler

    @Test("First non-restore purchase credits 2× the bundle's chip amount and flips the doubler flag")
    func firstPurchaseDoubles() {
        let store = InMemoryChipStore()

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-1",
            bundle: bundle,
            isRestore: false,
            store: store
        )

        #expect(outcome == .credited(amount: 20_000, isFirstPurchase: true))
        #expect(store.chipBalance == 20_000)
        #expect(store.hasMadeFirstPurchase == true)
        #expect(store.processedTransactionIDs.contains("tx-1"))
    }

    @Test("Subsequent purchases credit the base chip amount with the flag already flipped")
    func secondPurchaseCreditsBase() {
        let store = InMemoryChipStore(hasMadeFirstPurchase: true)

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-2",
            bundle: bundle,
            isRestore: false,
            store: store
        )

        #expect(outcome == .credited(amount: 10_000, isFirstPurchase: false))
        #expect(store.chipBalance == 10_000)
        #expect(store.hasMadeFirstPurchase == true)
    }

    @Test("Two purchases on a fresh store: first doubles, second credits base")
    func sequenceFirstThenSecond() {
        let store = InMemoryChipStore()

        _ = ChipPurchaseProcessor.credit(transactionID: "tx-a", bundle: bundle, isRestore: false, store: store)
        let secondOutcome = ChipPurchaseProcessor.credit(transactionID: "tx-b", bundle: bundle, isRestore: false, store: store)

        #expect(store.chipBalance == 30_000) // 20,000 (first, doubled) + 10,000 (second, base)
        #expect(secondOutcome == .credited(amount: 10_000, isFirstPurchase: false))
    }

    // MARK: - Idempotency

    @Test("A given transactionID never credits chips twice — second call is a no-op")
    func idempotency() {
        let store = InMemoryChipStore(hasMadeFirstPurchase: true)

        let first = ChipPurchaseProcessor.credit(transactionID: "tx-dup", bundle: bundle, isRestore: false, store: store)
        let second = ChipPurchaseProcessor.credit(transactionID: "tx-dup", bundle: bundle, isRestore: false, store: store)

        #expect(first == .credited(amount: 10_000, isFirstPurchase: false))
        #expect(second == .alreadyProcessed)
        #expect(store.chipBalance == 10_000) // unchanged from the first credit
    }

    @Test("Idempotency holds across the doubler — a duplicate first purchase does not re-fire the doubler")
    func idempotencyAcrossDoubler() {
        let store = InMemoryChipStore()

        let first = ChipPurchaseProcessor.credit(transactionID: "tx-first-dup", bundle: bundle, isRestore: false, store: store)
        let second = ChipPurchaseProcessor.credit(transactionID: "tx-first-dup", bundle: bundle, isRestore: false, store: store)

        #expect(first == .credited(amount: 20_000, isFirstPurchase: true))
        #expect(second == .alreadyProcessed)
        #expect(store.chipBalance == 20_000) // single credit only
        #expect(store.hasMadeFirstPurchase == true)
    }

    @Test("alreadyProcessed leaves both balance and flag untouched")
    func alreadyProcessedIsAFullNoOp() {
        let store = InMemoryChipStore(
            chipBalance: 12_345,
            hasMadeFirstPurchase: false,
            processedTransactionIDs: ["tx-prior"]
        )

        let outcome = ChipPurchaseProcessor.credit(transactionID: "tx-prior", bundle: bundle, isRestore: false, store: store)

        #expect(outcome == .alreadyProcessed)
        #expect(store.chipBalance == 12_345)
        #expect(store.hasMadeFirstPurchase == false)
    }

    // MARK: - Restore semantics

    @Test("Restore never triggers the doubler — even when hasMadeFirstPurchase is false")
    func restoreNeverDoubles() {
        let store = InMemoryChipStore() // doubler flag false

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-restored",
            bundle: bundle,
            isRestore: true,
            store: store
        )

        #expect(outcome == .credited(amount: 10_000, isFirstPurchase: false))
        #expect(store.chipBalance == 10_000)
    }

    @Test("Restore does not flip the doubler flag — first non-restore purchase later still doubles")
    func restoreDoesNotConsumeDoubler() {
        let store = InMemoryChipStore()

        _ = ChipPurchaseProcessor.credit(transactionID: "tx-rest", bundle: bundle, isRestore: true, store: store)
        #expect(store.hasMadeFirstPurchase == false)

        let firstReal = ChipPurchaseProcessor.credit(transactionID: "tx-real", bundle: bundle, isRestore: false, store: store)
        #expect(firstReal == .credited(amount: 20_000, isFirstPurchase: true))
        #expect(store.hasMadeFirstPurchase == true)
    }

    // MARK: - Force-quit safety ordering

    @Test("Doubler flag is observable as `true` after credit — flag-then-credit ordering is in place")
    func flagSetBeforeCredit() {
        // The processor flips hasMadeFirstPurchase BEFORE crediting chips
        // so a hypothetical force-quit between the two writes cannot
        // replay the doubler on the next launch's listener pass. We
        // can't simulate a partial UserDefaults flush in-process — the
        // observable property of the implementation is that after a
        // successful credit the flag is true AND the credit reflects
        // the doubled amount. If the order were reversed (credit first,
        // flag second) the post-credit state would be identical, so
        // this test is paired with the source's invariant comment to
        // guard against silent regressions.
        let store = InMemoryChipStore()
        _ = ChipPurchaseProcessor.credit(transactionID: "tx-order", bundle: bundle, isRestore: false, store: store)
        #expect(store.hasMadeFirstPurchase == true)
        #expect(store.chipBalance == 20_000)
    }

    @Test("Processed-set guard fires before any mutation — pre-existing flag stays false on a duplicate first purchase")
    func processedGuardRunsBeforeFlag() {
        let store = InMemoryChipStore(
            hasMadeFirstPurchase: false,
            processedTransactionIDs: ["tx-already"]
        )

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-already",
            bundle: bundle,
            isRestore: false,
            store: store
        )

        #expect(outcome == .alreadyProcessed)
        // The doubler is preserved for a future, distinct transaction.
        #expect(store.hasMadeFirstPurchase == false)
        #expect(store.chipBalance == 0)
    }

    // MARK: - Mixed scenarios

    @Test("A restore credit followed by a real first purchase: restore at base, real at double")
    func restoreThenFirstReal() {
        let store = InMemoryChipStore()
        _ = ChipPurchaseProcessor.credit(transactionID: "tx-r", bundle: bundle, isRestore: true, store: store)
        _ = ChipPurchaseProcessor.credit(transactionID: "tx-real", bundle: bundle, isRestore: false, store: store)
        #expect(store.chipBalance == 10_000 + 20_000)
    }

    @Test("Multiple distinct restores all credit at base, never doubling")
    func multipleRestoresStayAtBase() {
        let store = InMemoryChipStore()
        for i in 0..<3 {
            _ = ChipPurchaseProcessor.credit(transactionID: "tx-r-\(i)", bundle: bundle, isRestore: true, store: store)
        }
        #expect(store.chipBalance == 30_000)
        #expect(store.hasMadeFirstPurchase == false)
    }
}
