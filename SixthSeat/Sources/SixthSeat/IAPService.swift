import Foundation

/// External boundary for in-app purchases. Production conforms via
/// `StoreKitIAPService` (real StoreKit 2); tests conform via
/// `InMemoryIAPService` (configurable success / cancel / failure paths).
///
/// All four chip-credit invariants live in `ChipPurchaseProcessor` so
/// both implementations route success paths through the same code —
/// the test double cannot drift from production semantics.
public protocol IAPService: AnyObject, Sendable {

    /// Refresh `localizedPrice` for every catalog tier from the App
    /// Store. Returns the catalog with `Product.displayPrice` substituted
    /// in. Any tier whose product is not found in the store keeps its
    /// catalog placeholder.
    func loadProducts() async throws -> [ChipBundle]

    /// Initiate a purchase for the given bundle. Crediting (with
    /// idempotency + first-purchase doubler) is performed inside the
    /// service before returning so the caller can rely on
    /// `chipStore.chipBalance` reflecting the new total on
    /// `.success`. The returned `creditedAmount` is the post-doubler
    /// figure; `0` when the transaction was already processed
    /// (deduped).
    func purchase(_ bundle: ChipBundle) async throws -> PurchaseResult

    /// Apple-required restore affordance. For consumables this is
    /// mostly a no-op — finished consumable transactions do not
    /// re-emit. The implementation flushes pending unfinished
    /// transactions through the same credit path (with `isRestore =
    /// true` so the doubler does not re-fire) and returns the count
    /// that actually credited chips on this call.
    func restore() async throws -> Int

    /// Start the long-running listener over `Transaction.updates`. Called
    /// once at app launch. Idempotent — calling twice cancels the
    /// previous listener task before installing a new one.
    func startTransactionListener()
}

/// Shape of a `purchase` outcome. Aligns with the four states a real
/// StoreKit purchase can land in — success, user cancelled, pending
/// (Ask to Buy / parental approval), or failure — plus a structured
/// error case for surfacing UX-relevant copy.
public enum PurchaseResult: Equatable, Sendable {
    case success(creditedAmount: Int, isFirstPurchase: Bool)
    case userCancelled
    case pending
    case failed(IAPError)
}

/// Failure modes the Chip Shop view distinguishes. `unknown` carries
/// a free-form description for telemetry; the UI collapses everything
/// to a single "Purchase failed. Try again." line.
public enum IAPError: Error, Equatable, Sendable {
    case productNotFound
    case verificationFailed
    case networkError
    case unknown(String)
}

/// Configurable test double. Tests script `nextPurchaseResult` to
/// simulate each path; the in-memory chip store captures the credit
/// side effects. Not thread-safe — tests are serial.
public final class InMemoryIAPService: IAPService, @unchecked Sendable {

    public enum Scripted: Equatable {
        case success
        case userCancelled
        case pending
        case verificationFailure
        case networkError
    }

    public var catalog: [ChipBundle]
    public var nextPurchaseResult: Scripted = .success
    public var loadProductsThrows: Error?
    public var nextTransactionID: String = "test-tx-1"
    public var restoreReturns: Int = 0
    public var restoreThrows: Error?

    public private(set) var purchaseCallCount: Int = 0
    public private(set) var restoreCallCount: Int = 0
    public private(set) var loadProductsCallCount: Int = 0
    public private(set) var listenerStartedCount: Int = 0

    private let chipStore: ChipStoreProtocol
    private let telemetry: TelemetryService

    public init(
        chipStore: ChipStoreProtocol,
        telemetry: TelemetryService = RecordingTelemetryService(),
        catalog: [ChipBundle] = ChipBundleCatalog.all
    ) {
        self.chipStore = chipStore
        self.telemetry = telemetry
        self.catalog = catalog
    }

    public func loadProducts() async throws -> [ChipBundle] {
        loadProductsCallCount += 1
        if let error = loadProductsThrows { throw error }
        return catalog
    }

    public func purchase(_ bundle: ChipBundle) async throws -> PurchaseResult {
        purchaseCallCount += 1
        telemetry.purchaseInitiated(productID: bundle.id)

        switch nextPurchaseResult {
        case .success:
            let outcome = ChipPurchaseProcessor.credit(
                transactionID: nextTransactionID,
                bundle: bundle,
                isRestore: false,
                store: chipStore
            )
            switch outcome {
            case .credited(let amount, let isFirstPurchase):
                telemetry.purchaseSucceeded(productID: bundle.id, isFirstPurchase: isFirstPurchase)
                return .success(creditedAmount: amount, isFirstPurchase: isFirstPurchase)
            case .alreadyProcessed:
                telemetry.purchaseSucceeded(productID: bundle.id, isFirstPurchase: false)
                return .success(creditedAmount: 0, isFirstPurchase: false)
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        case .verificationFailure:
            telemetry.purchaseFailed(productID: bundle.id, reason: "verificationFailed")
            return .failed(.verificationFailed)
        case .networkError:
            telemetry.purchaseFailed(productID: bundle.id, reason: "networkError")
            return .failed(.networkError)
        }
    }

    public func restore() async throws -> Int {
        restoreCallCount += 1
        telemetry.restoreInitiated()
        if let error = restoreThrows { throw error }
        telemetry.restoreCompleted(count: restoreReturns)
        return restoreReturns
    }

    public func startTransactionListener() {
        listenerStartedCount += 1
    }
}
