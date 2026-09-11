import Foundation

/// Pure credit pipeline shared by `StoreKitIAPService` and the in-memory
/// test double. Owns the IAP idempotency invariant:
///
/// **Idempotency.** A given `transactionID` never credits twice. The
/// processed-set guard at the top of `credit` is the load-bearing
/// defense against listener replay, restore re-emission, and Family
/// Sharing redelivery. `isRestore` is accepted for call-site symmetry
/// but no longer changes the credited amount — every purchase and
/// restore credits exactly the tier's nominal chip amount.
public enum ChipPurchaseProcessor {

    public enum Outcome: Equatable, Sendable {
        case credited(amount: Int)
        case alreadyProcessed
    }

    @discardableResult
    public static func credit(
        transactionID: String,
        bundle: ChipBundle,
        isRestore: Bool,
        store: ChipStoreProtocol
    ) -> Outcome {
        let amount = bundle.chipAmount
        guard store.creditPurchase(transactionID: transactionID, amount: amount) else {
            return .alreadyProcessed
        }
        return .credited(amount: amount)
    }
}
