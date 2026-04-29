import Foundation
import Testing
@testable import SixthSeat

@Suite("InMemoryIAPService")
struct InMemoryIAPServiceTests {

    private func makeService(
        store: InMemoryChipStore = InMemoryChipStore()
    ) -> (InMemoryIAPService, InMemoryChipStore, RecordingTelemetryService) {
        let telemetry = RecordingTelemetryService()
        let service = InMemoryIAPService(chipStore: store, telemetry: telemetry)
        return (service, store, telemetry)
    }

    private let bundle = ChipBundleCatalog.starter

    // MARK: - Load

    @Test("loadProducts returns the catalog by default")
    func loadProductsReturnsCatalog() async throws {
        let (service, _, _) = makeService()
        let bundles = try await service.loadProducts()
        #expect(bundles.count == ChipBundleCatalog.all.count)
        #expect(bundles.map(\.id) == ChipBundleCatalog.all.map(\.id))
    }

    @Test("loadProducts throws when scripted to throw")
    func loadProductsThrows() async {
        let (service, _, _) = makeService()
        struct BoomError: Error {}
        service.loadProductsThrows = BoomError()

        do {
            _ = try await service.loadProducts()
            Issue.record("expected loadProducts to throw")
        } catch is BoomError {
            // ok
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - Purchase paths

    @Test("Successful purchase credits chips through the processor and records telemetry")
    func purchaseSuccess() async throws {
        let (service, store, telemetry) = makeService()
        service.nextPurchaseResult = .success
        service.nextTransactionID = "tx-success-1"

        let result = try await service.purchase(bundle)

        #expect(result == .success(creditedAmount: bundle.chipAmount * 2, isFirstPurchase: true))
        #expect(store.chipBalance == bundle.chipAmount * 2)
        #expect(store.hasMadeFirstPurchase == true)
        #expect(store.processedTransactionIDs.contains("tx-success-1"))
        #expect(telemetry.events.contains(.purchaseInitiated(productID: bundle.id)))
        #expect(telemetry.events.contains(.purchaseSucceeded(productID: bundle.id, isFirstPurchase: true)))
    }

    @Test("User-cancelled purchase does not mutate the store and emits initiated but not succeeded")
    func purchaseUserCancelled() async throws {
        let (service, store, telemetry) = makeService()
        service.nextPurchaseResult = .userCancelled

        let result = try await service.purchase(bundle)

        #expect(result == .userCancelled)
        #expect(store.chipBalance == 0)
        #expect(store.hasMadeFirstPurchase == false)
        #expect(telemetry.events.contains(.purchaseInitiated(productID: bundle.id)))
        let succeeded = telemetry.events.filter { if case .purchaseSucceeded = $0 { return true } else { return false } }
        #expect(succeeded.isEmpty)
    }

    @Test("Pending purchase (Ask to Buy) returns .pending and leaves the store untouched")
    func purchasePending() async throws {
        let (service, store, _) = makeService()
        service.nextPurchaseResult = .pending

        let result = try await service.purchase(bundle)

        #expect(result == .pending)
        #expect(store.chipBalance == 0)
        #expect(store.hasMadeFirstPurchase == false)
    }

    @Test("Verification failure returns .failed(.verificationFailed) and records the failure telemetry")
    func purchaseVerificationFailure() async throws {
        let (service, store, telemetry) = makeService()
        service.nextPurchaseResult = .verificationFailure

        let result = try await service.purchase(bundle)

        #expect(result == .failed(.verificationFailed))
        #expect(store.chipBalance == 0)
        #expect(telemetry.events.contains(.purchaseFailed(productID: bundle.id, reason: "verificationFailed")))
    }

    @Test("Network error returns .failed(.networkError) and records the failure telemetry")
    func purchaseNetworkError() async throws {
        let (service, store, telemetry) = makeService()
        service.nextPurchaseResult = .networkError

        let result = try await service.purchase(bundle)

        #expect(result == .failed(.networkError))
        #expect(store.chipBalance == 0)
        #expect(telemetry.events.contains(.purchaseFailed(productID: bundle.id, reason: "networkError")))
    }

    @Test("A duplicate successful purchase (same nextTransactionID) credits once and reports 0 on the dedup")
    func duplicateTransactionDeduped() async throws {
        let (service, store, _) = makeService()
        service.nextPurchaseResult = .success
        service.nextTransactionID = "tx-once"

        _ = try await service.purchase(bundle)
        let secondResult = try await service.purchase(bundle)

        #expect(secondResult == .success(creditedAmount: 0, isFirstPurchase: false))
        #expect(store.chipBalance == bundle.chipAmount * 2) // first credit only
    }

    // MARK: - Restore

    @Test("Restore returns the scripted count and records initiated + completed telemetry")
    func restoreReturnsCount() async throws {
        let (service, _, telemetry) = makeService()
        service.restoreReturns = 3

        let count = try await service.restore()

        #expect(count == 3)
        #expect(telemetry.events.contains(.restoreInitiated))
        #expect(telemetry.events.contains(.restoreCompleted(count: 3)))
    }

    @Test("Restore throws when scripted to throw")
    func restoreThrows() async {
        let (service, _, _) = makeService()
        struct RestoreBoom: Error {}
        service.restoreThrows = RestoreBoom()

        do {
            _ = try await service.restore()
            Issue.record("expected restore to throw")
        } catch is RestoreBoom {
            // ok
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - Listener

    @Test("startTransactionListener increments the listener-started count")
    func listenerStarts() {
        let (service, _, _) = makeService()
        service.startTransactionListener()
        service.startTransactionListener()
        #expect(service.listenerStartedCount == 2)
    }

    // MARK: - Call counters

    @Test("purchase / restore / loadProducts call counters tick on each call")
    func callCountersTick() async throws {
        let (service, _, _) = makeService()
        _ = try await service.loadProducts()
        _ = try await service.loadProducts()
        _ = try await service.purchase(bundle)
        _ = try await service.restore()

        #expect(service.loadProductsCallCount == 2)
        #expect(service.purchaseCallCount == 1)
        #expect(service.restoreCallCount == 1)
    }
}
