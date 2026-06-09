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

    // MARK: - Crediting

    @Test("A purchase credits the bundle's nominal chip amount")
    func purchaseCreditsNominalAmount() {
        let store = InMemoryChipStore()

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-1",
            bundle: bundle,
            isRestore: false,
            store: store
        )

        #expect(outcome == .credited(amount: 10_000))
        #expect(store.chipBalance == 10_000)
        #expect(store.processedTransactionIDs.contains("tx-1"))
    }

    @Test("Two distinct purchases each credit the nominal amount")
    func twoPurchasesEachCreditNominal() {
        let store = InMemoryChipStore()

        _ = ChipPurchaseProcessor.credit(transactionID: "tx-a", bundle: bundle, isRestore: false, store: store)
        let second = ChipPurchaseProcessor.credit(transactionID: "tx-b", bundle: bundle, isRestore: false, store: store)

        #expect(store.chipBalance == 20_000) // 10,000 + 10,000
        #expect(second == .credited(amount: 10_000))
    }

    // MARK: - Idempotency

    @Test("A given transactionID never credits chips twice — second call is a no-op")
    func idempotency() {
        let store = InMemoryChipStore()

        let first = ChipPurchaseProcessor.credit(transactionID: "tx-dup", bundle: bundle, isRestore: false, store: store)
        let second = ChipPurchaseProcessor.credit(transactionID: "tx-dup", bundle: bundle, isRestore: false, store: store)

        #expect(first == .credited(amount: 10_000))
        #expect(second == .alreadyProcessed)
        #expect(store.chipBalance == 10_000) // unchanged from the first credit
    }

    @Test("alreadyProcessed leaves the balance untouched")
    func alreadyProcessedIsAFullNoOp() {
        let store = InMemoryChipStore(
            chipBalance: 12_345,
            processedTransactionIDs: ["tx-prior"]
        )

        let outcome = ChipPurchaseProcessor.credit(transactionID: "tx-prior", bundle: bundle, isRestore: false, store: store)

        #expect(outcome == .alreadyProcessed)
        #expect(store.chipBalance == 12_345)
    }

    @Test("Processed-set guard fires before any mutation — balance stays put on a duplicate")
    func processedGuardRunsBeforeMutation() {
        let store = InMemoryChipStore(
            processedTransactionIDs: ["tx-already"]
        )

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-already",
            bundle: bundle,
            isRestore: false,
            store: store
        )

        #expect(outcome == .alreadyProcessed)
        #expect(store.chipBalance == 0)
    }

    // MARK: - Restore semantics

    @Test("A restore credits the nominal amount, same as a purchase")
    func restoreCreditsNominalAmount() {
        let store = InMemoryChipStore()

        let outcome = ChipPurchaseProcessor.credit(
            transactionID: "tx-restored",
            bundle: bundle,
            isRestore: true,
            store: store
        )

        #expect(outcome == .credited(amount: 10_000))
        #expect(store.chipBalance == 10_000)
    }

    @Test("Multiple distinct restores each credit the nominal amount")
    func multipleRestoresEachCreditNominal() {
        let store = InMemoryChipStore()
        for i in 0..<3 {
            _ = ChipPurchaseProcessor.credit(transactionID: "tx-r-\(i)", bundle: bundle, isRestore: true, store: store)
        }
        #expect(store.chipBalance == 30_000)
    }
}
