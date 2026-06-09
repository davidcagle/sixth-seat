import Foundation

/// External boundary for in-app purchases. Production conforms via
/// `StoreKitIAPService` (real StoreKit 2); tests conform via
/// `InMemoryIAPService` (configurable success / cancel / failure paths).
///
/// The chip-credit invariant (idempotency) lives in
/// `ChipPurchaseProcessor` so both implementations route success paths
/// through the same code — the test double cannot drift from production
/// semantics.
public protocol IAPService: AnyObject, Sendable {

    /// Refresh `localizedPrice` for every catalog tier from the App
    /// Store. Returns the catalog with `Product.displayPrice` substituted
    /// in. Any tier whose product is not found in the store keeps its
    /// catalog placeholder.
    func loadProducts() async throws -> [ChipBundle]

    /// Initiate a purchase for the given bundle. Crediting (idempotent
    /// via the processed-transaction guard) is performed inside the
    /// service before returning so the caller can rely on
    /// `chipStore.chipBalance` reflecting the new total on
    /// `.success`. The returned `creditedAmount` is the tier's nominal
    /// chip amount; `0` when the transaction was already processed
    /// (deduped).
    func purchase(_ bundle: ChipBundle) async throws -> PurchaseResult

    /// Apple-required restore affordance. For consumables this is
    /// mostly a no-op — finished consumable transactions do not
    /// re-emit. The implementation flushes pending unfinished
    /// transactions through the same credit path and returns the count
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
    case success(creditedAmount: Int)
    case userCancelled
    case pending
    case failed(IAPError)
}

/// Failure modes the Chip Shop view distinguishes. Each case maps to a
/// dedicated user-facing line via `ChipShopLogic.purchaseFailureMessage`
/// and to a stable `telemetryType` token on the `iap.purchase.failed`
/// signal. `unknown` carries a free-form description (the underlying
/// StoreKit `localizedDescription`) for the default "Purchase failed:
/// …" copy and the `error_description` telemetry parameter.
public enum IAPError: Error, Equatable, Sendable {
    case productNotFound
    case productUnavailable
    case notEntitled
    case paymentNotAllowed
    case paymentInvalid
    case networkError
    case verificationFailed
    case unknown(String)

    /// Stable, low-cardinality token for the `error_type` telemetry
    /// parameter. Deliberately decoupled from the Swift case name so a
    /// future enum rename can't silently break dashboard aggregation.
    public var telemetryType: String {
        switch self {
        case .productNotFound: return "productNotFound"
        case .productUnavailable: return "productUnavailable"
        case .notEntitled: return "notEntitled"
        case .paymentNotAllowed: return "paymentNotAllowed"
        case .paymentInvalid: return "paymentInvalid"
        case .networkError: return "networkError"
        case .verificationFailed: return "verificationFailed"
        case .unknown: return "unknown"
        }
    }
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
        /// Inject an arbitrary structured failure so tests can exercise
        /// the per-case user copy without depending on real StoreKit
        /// error values (which are impractical to construct in tests).
        case failure(IAPError)
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
            case .credited(let amount):
                telemetry.purchaseSucceeded(productID: bundle.id)
                return .success(creditedAmount: amount)
            case .alreadyProcessed:
                telemetry.purchaseSucceeded(productID: bundle.id)
                return .success(creditedAmount: 0)
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        case .verificationFailure:
            return reportFailure(.verificationFailed, productID: bundle.id)
        case .networkError:
            return reportFailure(.networkError, productID: bundle.id)
        case .failure(let error):
            return reportFailure(error, productID: bundle.id)
        }
    }

    /// Emit the failure telemetry and wrap the error in a `PurchaseResult`
    /// using the same `errorType`/`description` shape the production
    /// service uses, so the test double can't drift from it.
    private func reportFailure(_ error: IAPError, productID: String) -> PurchaseResult {
        telemetry.purchaseFailed(
            productID: productID,
            errorType: error.telemetryType,
            description: error.telemetryType
        )
        return .failed(error)
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
