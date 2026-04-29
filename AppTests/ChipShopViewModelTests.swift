import Foundation
import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("ChipShopViewModel")
struct ChipShopViewModelTests {

    private func makeViewModel(
        balance: Int = 5_000,
        hasMadeFirstPurchase: Bool = false,
        scriptedPurchase: InMemoryIAPService.Scripted = .success
    ) -> (ChipShopViewModel, InMemoryChipStore, InMemoryIAPService, RecordingHapticsService) {
        let store = InMemoryChipStore(
            chipBalance: balance,
            hasReceivedStarterBonus: true,
            hasMadeFirstPurchase: hasMadeFirstPurchase
        )
        let telemetry = RecordingTelemetryService()
        let iap = InMemoryIAPService(chipStore: store, telemetry: telemetry)
        iap.nextPurchaseResult = scriptedPurchase
        let haptics = RecordingHapticsService()
        let vm = ChipShopViewModel(iapService: iap, chipStore: store, haptics: haptics)
        return (vm, store, iap, haptics)
    }

    // MARK: - Initial state

    @Test("Initial state mirrors the chip store")
    func initialStateMirrorsStore() {
        let (vm, _, _, _) = makeViewModel(balance: 12_000, hasMadeFirstPurchase: true)
        #expect(vm.balance == 12_000)
        #expect(vm.hasMadeFirstPurchase == true)
        #expect(vm.bundles.count == 5)
        #expect(vm.bundles == ChipBundleCatalog.all) // placeholder render before loadProducts
    }

    @Test("Doubler is active by default for a fresh install")
    func doublerActiveByDefault() {
        let (vm, _, _, _) = makeViewModel(hasMadeFirstPurchase: false)
        #expect(vm.doublerActive == true)
    }

    @Test("Doubler is inactive once hasMadeFirstPurchase is set")
    func doublerInactiveAfterFirstPurchase() {
        let (vm, _, _, _) = makeViewModel(hasMadeFirstPurchase: true)
        #expect(vm.doublerActive == false)
    }

    // MARK: - Display math

    @Test("displayAmount doubles the bundle while the doubler is active")
    func displayAmountDoublesUntilFirstPurchase() {
        let (vm, _, _, _) = makeViewModel(hasMadeFirstPurchase: false)
        let bundle = ChipBundleCatalog.starter
        #expect(vm.displayAmount(for: bundle) == bundle.chipAmount * 2)
        #expect(vm.strikethroughAmount(for: bundle) == bundle.chipAmount)
    }

    @Test("displayAmount returns the base amount once the doubler is consumed")
    func displayAmountAtBaseAfterFirstPurchase() {
        let (vm, _, _, _) = makeViewModel(hasMadeFirstPurchase: true)
        let bundle = ChipBundleCatalog.starter
        #expect(vm.displayAmount(for: bundle) == bundle.chipAmount)
        #expect(vm.strikethroughAmount(for: bundle) == nil)
    }

    // MARK: - Load products

    @Test("loadProductsIfNeeded refreshes prices in catalog order")
    func loadProductsRefreshesPrices() async {
        let (vm, store, iap, _) = makeViewModel()
        var custom = ChipBundleCatalog.all
        for index in custom.indices {
            custom[index].localizedPrice = "REFRESHED"
        }
        iap.catalog = custom

        await vm.loadProductsIfNeeded()

        #expect(vm.bundles.map(\.localizedPrice) == Array(repeating: "REFRESHED", count: ChipBundleCatalog.all.count))
        #expect(vm.bundles.map(\.id) == ChipBundleCatalog.all.map(\.id))
        _ = store // suppress unused warning if any
    }

    @Test("loadProductsIfNeeded keeps placeholder prices when loading throws")
    func loadProductsFailureKeepsPlaceholders() async {
        let (vm, _, iap, _) = makeViewModel()
        struct Boom: Error {}
        iap.loadProductsThrows = Boom()
        let placeholdersBefore = vm.bundles.map(\.localizedPrice)

        await vm.loadProductsIfNeeded()

        #expect(vm.bundles.map(\.localizedPrice) == placeholdersBefore)
    }

    // MARK: - Purchase paths

    @Test("Successful purchase credits chips, refreshes balance, flips doubler, and fires .success haptic")
    func successfulPurchase() async {
        let (vm, store, _, haptics) = makeViewModel(balance: 1_000, scriptedPurchase: .success)
        let bundle = ChipBundleCatalog.starter

        await vm.purchase(bundle)

        #expect(store.chipBalance == 1_000 + bundle.chipAmount * 2)
        #expect(vm.balance == store.chipBalance)
        #expect(vm.hasMadeFirstPurchase == true)
        #expect(vm.doublerActive == false)
        #expect(haptics.events.contains(.notification(.success)))
        #expect(vm.errorMessage(for: bundle) == nil)
    }

    @Test("User-cancelled purchase leaves balance and flag untouched and fires no haptic")
    func userCancelledPurchase() async {
        let (vm, store, _, haptics) = makeViewModel(scriptedPurchase: .userCancelled)
        let bundle = ChipBundleCatalog.starter
        let before = store.chipBalance

        await vm.purchase(bundle)

        #expect(store.chipBalance == before)
        #expect(vm.hasMadeFirstPurchase == false)
        #expect(haptics.events.isEmpty)
    }

    @Test("Pending purchase surfaces the pending message inline")
    func pendingPurchase() async {
        let (vm, _, _, _) = makeViewModel(scriptedPurchase: .pending)
        let bundle = ChipBundleCatalog.starter

        await vm.purchase(bundle)

        #expect(vm.errorMessage(for: bundle) == "Purchase pending approval.")
    }

    @Test("Verification failure surfaces a generic Try again message")
    func verificationFailurePurchase() async {
        let (vm, _, _, _) = makeViewModel(scriptedPurchase: .verificationFailure)
        let bundle = ChipBundleCatalog.starter

        await vm.purchase(bundle)

        #expect(vm.errorMessage(for: bundle) == "Purchase failed. Try again.")
    }

    @Test("Network error surfaces the same generic Try again message")
    func networkErrorPurchase() async {
        let (vm, _, _, _) = makeViewModel(scriptedPurchase: .networkError)
        let bundle = ChipBundleCatalog.starter

        await vm.purchase(bundle)

        #expect(vm.errorMessage(for: bundle) == "Purchase failed. Try again.")
    }

    @Test("Error for a tier is cleared on the next purchase attempt for that tier")
    func errorClearsOnRetry() async {
        let (vm, _, iap, _) = makeViewModel(scriptedPurchase: .networkError)
        let bundle = ChipBundleCatalog.starter

        await vm.purchase(bundle)
        #expect(vm.errorMessage(for: bundle) == "Purchase failed. Try again.")

        iap.nextPurchaseResult = .success
        await vm.purchase(bundle)
        #expect(vm.errorMessage(for: bundle) == nil)
    }

    @Test("Same-transactionID re-tap dedupes through the engine — service is called twice but chips credit once")
    func duplicateTransactionDedupes() async {
        let (vm, _, iap, _) = makeViewModel(balance: 0, scriptedPurchase: .success)
        let bundle = ChipBundleCatalog.starter

        // The view model awaits each purchase serially in this test (the
        // in-memory service completes synchronously). Both calls reuse
        // `nextTransactionID`, so the engine's processed-set guard
        // prevents the second credit. Counter ticks twice (the service
        // was called twice), but chips credit once — the load-bearing
        // idempotency invariant verified end-to-end through the VM.
        await vm.purchase(bundle)
        await vm.purchase(bundle)

        #expect(iap.purchaseCallCount == 2)
        #expect(vm.balance == bundle.chipAmount * 2) // first credit only (doubled)
    }

    // MARK: - Restore

    @Test("Restore calls the service and surfaces a No purchases to restore message on zero")
    func restoreZero() async {
        let (vm, _, iap, _) = makeViewModel()
        iap.restoreReturns = 0

        await vm.restore()

        #expect(iap.restoreCallCount == 1)
        #expect(vm.restoreMessage == "No purchases to restore.")
        #expect(vm.isRestoring == false)
    }

    @Test("Restore surfaces a singular message for one purchase")
    func restoreOne() async {
        let (vm, _, iap, _) = makeViewModel()
        iap.restoreReturns = 1

        await vm.restore()

        #expect(vm.restoreMessage == "Restored 1 purchase.")
    }

    @Test("Restore surfaces a plural message for multiple purchases")
    func restoreMany() async {
        let (vm, _, iap, _) = makeViewModel()
        iap.restoreReturns = 4

        await vm.restore()

        #expect(vm.restoreMessage == "Restored 4 purchases.")
    }

    @Test("Restore failure surfaces the generic Try again message")
    func restoreThrows() async {
        let (vm, _, iap, _) = makeViewModel()
        struct RestoreBoom: Error {}
        iap.restoreThrows = RestoreBoom()

        await vm.restore()

        #expect(vm.restoreMessage == "Restore failed. Try again.")
        #expect(vm.isRestoring == false)
    }

    @Test("Restore refreshes the balance from the store on completion")
    func restoreRefreshesBalance() async {
        let (vm, store, iap, _) = makeViewModel(balance: 1_000)
        iap.restoreReturns = 0
        store.chipBalance = 9_999 // simulate the listener crediting in the background

        await vm.restore()

        #expect(vm.balance == 9_999)
    }
}
