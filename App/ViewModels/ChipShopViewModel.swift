import Foundation
import Observation
import SixthSeat

/// View model backing the real Chip Shop screen. Owns the per-tier
/// loading and error state, observes the chip balance + first-purchase
/// flag for banner toggling, and routes purchase/restore intents into
/// the injected `IAPService`. Engine business rules (doubler,
/// idempotency, telemetry) live in the engine — this layer only
/// translates between user intents and engine surface.
@Observable
@MainActor
final class ChipShopViewModel {

    private let iapService: IAPService
    private let chipStore: ChipStoreProtocol
    private let haptics: HapticsService

    /// Catalog as currently rendered. Initialised from
    /// `ChipBundleCatalog.all` so the screen renders immediately with
    /// placeholder prices, then refreshed in-place once
    /// `loadProducts()` returns with `Product.displayPrice` values.
    private(set) var bundles: [ChipBundle] = ChipBundleCatalog.all
    private(set) var balance: Int
    private(set) var hasMadeFirstPurchase: Bool

    /// Bundle id currently in-flight. Drives per-card spinner + button
    /// disable. Only one purchase can be in flight at a time.
    private(set) var loadingBundleID: String?

    /// Per-bundle inline error string. Cleared on the next purchase
    /// attempt for that tier. The view collapses every failure mode to
    /// the same generic "Purchase failed. Try again." copy.
    private(set) var errorByBundleID: [String: String] = [:]

    private(set) var isRestoring: Bool = false
    private(set) var restoreMessage: String?

    init(
        iapService: IAPService,
        chipStore: ChipStoreProtocol,
        haptics: HapticsService
    ) {
        self.iapService = iapService
        self.chipStore = chipStore
        self.haptics = haptics
        self.balance = chipStore.chipBalance
        self.hasMadeFirstPurchase = chipStore.hasMadeFirstPurchase
    }

    // MARK: - Intents

    func loadProductsIfNeeded() async {
        do {
            let refreshed = try await iapService.loadProducts()
            // Preserve catalog order even if the service ever reorders.
            let priceByID = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.id, $0.localizedPrice) })
            bundles = ChipBundleCatalog.all.map { catalogBundle in
                var copy = catalogBundle
                if let price = priceByID[catalogBundle.id] {
                    copy.localizedPrice = price
                }
                return copy
            }
        } catch {
            // Keep placeholder prices — the cards still render, the buttons
            // still tap. Don't surface a banner-level error for product-load
            // failures; many will resolve transparently on retry.
        }
    }

    func purchase(_ bundle: ChipBundle) async {
        guard loadingBundleID == nil else { return }
        loadingBundleID = bundle.id
        errorByBundleID[bundle.id] = nil

        do {
            let result = try await iapService.purchase(bundle)
            switch result {
            case .success(let creditedAmount, _):
                if creditedAmount > 0 {
                    haptics.notification(.success)
                }
                refreshFromStore()
            case .userCancelled:
                break
            case .pending:
                errorByBundleID[bundle.id] = "Purchase pending approval."
            case .failed:
                errorByBundleID[bundle.id] = "Purchase failed. Try again."
            }
        } catch {
            errorByBundleID[bundle.id] = "Purchase failed. Try again."
        }

        loadingBundleID = nil
    }

    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        restoreMessage = nil

        do {
            let count = try await iapService.restore()
            restoreMessage = ChipShopLogic.restoreMessage(restoredCount: count)
            refreshFromStore()
        } catch {
            restoreMessage = "Restore failed. Try again."
        }

        isRestoring = false
    }

    // MARK: - Derived state for the view

    var doublerActive: Bool {
        ChipShopLogic.doublerActive(hasMadeFirstPurchase: hasMadeFirstPurchase)
    }

    func displayAmount(for bundle: ChipBundle) -> Int {
        ChipShopLogic.displayAmount(for: bundle, doublerActive: doublerActive)
    }

    func strikethroughAmount(for bundle: ChipBundle) -> Int? {
        ChipShopLogic.strikethroughAmount(for: bundle, doublerActive: doublerActive)
    }

    func isLoading(_ bundle: ChipBundle) -> Bool {
        loadingBundleID == bundle.id
    }

    func errorMessage(for bundle: ChipBundle) -> String? {
        errorByBundleID[bundle.id]
    }

    // MARK: - Internals

    private func refreshFromStore() {
        balance = chipStore.chipBalance
        hasMadeFirstPurchase = chipStore.hasMadeFirstPurchase
    }
}
