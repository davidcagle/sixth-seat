import Foundation
import StoreKit

/// Production `IAPService` backed by StoreKit 2's `Product` /
/// `Transaction` APIs. Verifies transaction signatures via
/// `VerificationResult` (client-side only — server-side validation is
/// V2). Crediting goes through `ChipPurchaseProcessor` so the doubler
/// and idempotency guards are identical to the test double.
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
            telemetry.purchaseFailed(productID: bundle.id, reason: "load: \(error.localizedDescription)")
            return .failed(.networkError)
        }

        guard let product = products.first else {
            telemetry.purchaseFailed(productID: bundle.id, reason: "productNotFound")
            return .failed(.productNotFound)
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            telemetry.purchaseFailed(productID: bundle.id, reason: error.localizedDescription)
            return .failed(.unknown(error.localizedDescription))
        }

        switch result {
        case .success(let verification):
            return await handleVerified(verification, bundle: bundle, isRestore: false)

        case .userCancelled:
            return .userCancelled

        case .pending:
            return .pending

        @unknown default:
            telemetry.purchaseFailed(productID: bundle.id, reason: "unknownStoreKitResult")
            return .failed(.unknown("unknown StoreKit result"))
        }
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
            case .credited(let amount, let isFirstPurchase):
                telemetry.purchaseSucceeded(productID: bundle.id, isFirstPurchase: isFirstPurchase)
                return .success(creditedAmount: amount, isFirstPurchase: isFirstPurchase)
            case .alreadyProcessed:
                telemetry.purchaseSucceeded(productID: bundle.id, isFirstPurchase: false)
                return .success(creditedAmount: 0, isFirstPurchase: false)
            }

        case .unverified(_, let error):
            telemetry.purchaseFailed(productID: bundle.id, reason: "verification: \(error.localizedDescription)")
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
        if case .credited(_, let isFirstPurchase) = outcome {
            telemetry.purchaseSucceeded(productID: bundle.id, isFirstPurchase: isFirstPurchase)
        }
    }
}
