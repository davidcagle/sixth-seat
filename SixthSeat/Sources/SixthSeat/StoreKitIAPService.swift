import Foundation
import StoreKit

/// Production `IAPService` backed by StoreKit 2's `Product` /
/// `Transaction` APIs. Verifies transaction signatures via
/// `VerificationResult` (client-side only — server-side validation is
/// V2). Crediting goes through `ChipPurchaseProcessor` so the
/// idempotency guard is identical to the test double.
public final class StoreKitIAPService: IAPService, @unchecked Sendable {

    private let chipStore: ChipStoreProtocol
    private let telemetry: TelemetryService
    private let catalog: [ChipBundle]

    private let listenerLock = NSLock()
    private var listenerTask: Task<Void, Never>?

    public init(
        chipStore: ChipStoreProtocol,
        telemetry: TelemetryService = LoggingTelemetryService(),
        catalog: [ChipBundle] = ChipBundleCatalog.all
    ) {
        self.chipStore = chipStore
        self.telemetry = telemetry
        self.catalog = catalog
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - IAPService

    public func loadProducts() async throws -> [ChipBundle] {
        let products = try await Product.products(for: catalog.map(\.id))
        let priceByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0.displayPrice) })

        return catalog.map { bundle in
            var copy = bundle
            if let displayPrice = priceByID[bundle.id] {
                copy.localizedPrice = displayPrice
            }
            return copy
        }
    }

    public func purchase(_ bundle: ChipBundle) async throws -> PurchaseResult {
        telemetry.purchaseInitiated(productID: bundle.id)

        let products: [Product]
        do {
            products = try await Product.products(for: [bundle.id])
        } catch {
            let iapError = Self.mapStoreKitError(error)
            telemetry.purchaseFailed(
                productID: bundle.id,
                errorType: iapError.telemetryType,
                description: "load: \(error.localizedDescription)"
            )
            return .failed(iapError)
        }

        guard let product = products.first else {
            telemetry.purchaseFailed(
                productID: bundle.id,
                errorType: IAPError.productNotFound.telemetryType,
                description: "no product returned for \(bundle.id)"
            )
            return .failed(.productNotFound)
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            // A cancel thrown from `purchase()` is a user action, not a
            // failure — surface it silently like the `.userCancelled`
            // result case below rather than logging a failure.
            if let skError = error as? StoreKitError, case .userCancelled = skError {
                return .userCancelled
            }
            let iapError = Self.mapStoreKitError(error)
            telemetry.purchaseFailed(
                productID: bundle.id,
                errorType: iapError.telemetryType,
                description: error.localizedDescription
            )
            return .failed(iapError)
        }

        switch result {
        case .success(let verification):
            return await handleVerified(verification, bundle: bundle, isRestore: false)

        case .userCancelled:
            return .userCancelled

        case .pending:
            return .pending

        @unknown default:
            telemetry.purchaseFailed(
                productID: bundle.id,
                errorType: IAPError.unknown("unknownStoreKitResult").telemetryType,
                description: "unknown StoreKit purchase result"
            )
            return .failed(.unknown("unknown StoreKit result"))
        }
    }

    /// Translate a thrown StoreKit error into the engine's structured
    /// `IAPError` so the Chip Shop can show a cause-specific line. Covers
    /// both `StoreKitError` (storefront / entitlement / connectivity) and
    /// `Product.PurchaseError` (purchase-flow rejections); anything else
    /// falls through to `.unknown` carrying the raw description.
    static func mapStoreKitError(_ error: Error) -> IAPError {
        if let skError = error as? StoreKitError {
            switch skError {
            case .networkError:
                return .networkError
            case .notEntitled:
                return .notEntitled
            case .notAvailableInStorefront:
                return .productUnavailable
            case .userCancelled:
                // Callers handle cancel before reaching here; if it does
                // arrive, treat it as a non-actionable unknown rather than
                // inventing a failure line.
                return .unknown("userCancelled")
            case .systemError, .unknown:
                return .unknown(error.localizedDescription)
            @unknown default:
                return .unknown(error.localizedDescription)
            }
        }

        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return .productUnavailable
            case .purchaseNotAllowed:
                return .paymentNotAllowed
            case .invalidQuantity,
                 .ineligibleForOffer,
                 .invalidOfferIdentifier,
                 .invalidOfferPrice,
                 .invalidOfferSignature,
                 .missingOfferParameters:
                return .unknown(error.localizedDescription)
            @unknown default:
                return .unknown(error.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }

    public func restore() async throws -> Int {
        telemetry.restoreInitiated()

        do {
            try await AppStore.sync()
        } catch {
            telemetry.restoreCompleted(count: 0)
            throw IAPError.unknown(error.localizedDescription)
        }

        var creditedCount = 0
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            guard let bundle = catalog.first(where: { $0.id == transaction.productID }) else {
                await transaction.finish()
                continue
            }
            let outcome = ChipPurchaseProcessor.credit(
                transactionID: String(transaction.id),
                bundle: bundle,
                isRestore: true,
                store: chipStore
            )
            await transaction.finish()
            if case .credited = outcome { creditedCount += 1 }
        }

        telemetry.restoreCompleted(count: creditedCount)
        return creditedCount
    }

    public func startTransactionListener() {
        listenerLock.lock()
        listenerTask?.cancel()
        listenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                await self.processBackgroundTransaction(transaction)
            }
        }
        listenerLock.unlock()
    }

    // MARK: - Internals

    private func handleVerified(
        _ verification: VerificationResult<Transaction>,
        bundle: ChipBundle,
        isRestore: Bool
    ) async -> PurchaseResult {
        switch verification {
        case .verified(let transaction):
            let outcome = ChipPurchaseProcessor.credit(
                transactionID: String(transaction.id),
                bundle: bundle,
                isRestore: isRestore,
                store: chipStore
            )
            await transaction.finish()

            switch outcome {
            case .credited(let amount):
                telemetry.purchaseSucceeded(productID: bundle.id)
                return .success(creditedAmount: amount)
            case .alreadyProcessed:
                telemetry.purchaseSucceeded(productID: bundle.id)
                return .success(creditedAmount: 0)
            }

        case .unverified(_, let error):
            telemetry.purchaseFailed(
                productID: bundle.id,
                errorType: IAPError.verificationFailed.telemetryType,
                description: "verification: \(error.localizedDescription)"
            )
            return .failed(.verificationFailed)
        }
    }

    private func processBackgroundTransaction(_ transaction: Transaction) async {
        guard let bundle = catalog.first(where: { $0.id == transaction.productID }) else {
            await transaction.finish()
            return
        }
        let outcome = ChipPurchaseProcessor.credit(
            transactionID: String(transaction.id),
            bundle: bundle,
            isRestore: false,
            store: chipStore
        )
        await transaction.finish()
        if case .credited = outcome {
            telemetry.purchaseSucceeded(productID: bundle.id)
        }
    }
}
