import Foundation

/// Pure credit pipeline shared by `StoreKitIAPService` and the in-memory
/// test double. Owns the three IAP business invariants:
///
/// 1. **Idempotency.** A given `transactionID` never credits twice. The
///    processed-set guard at the top of `credit` is the load-bearing
///    defense against listener replay, restore re-emission, and Family
///    Sharing redelivery.
///
/// 2. **First-purchase doubler.** While `store.hasMadeFirstPurchase` is
///    `false` and the credit is not a restore, the chip amount is
///    doubled. Restores never re-fire the doubler — the flag was
///    already consumed when the underlying purchase originally
///    happened.
///
/// 3. **Force-quit safety.** The doubler flag is flipped to `true`
///    *before* chips are credited. A force-quit between flag-set and
///    credit costs the player the doubler bonus on replay (the
///    listener will credit at base amount), but cannot result in a
///    double-doubled credit. This mirrors the
///    `hasReceivedSecondChanceBonus` pattern from Session 12b.
public enum ChipPurchaseProcessor {

    public enum Outcome: Equatable, Sendable {
        case credited(amount: Int, isFirstPurchase: Bool)
        case alreadyProcessed
    }

    @discardableResult
    public static func credit(
        transactionID: String,
        bundle: ChipBundle,
        isRestore: Bool,
        store: ChipStoreProtocol
    ) -> Outcome {
        if store.processedTransactionIDs.contains(transactionID) {
            return .alreadyProcessed
        }

        let applyDoubler = !isRestore && !store.hasMadeFirstPurchase
        let amount = applyDoubler ? bundle.chipAmount * 2 : bundle.chipAmount

        if applyDoubler {
            store.hasMadeFirstPurchase = true
        }

        store.chipBalance += amount

        var ids = store.processedTransactionIDs
        ids.insert(transactionID)
        store.processedTransactionIDs = ids

        return .credited(amount: amount, isFirstPurchase: applyDoubler)
    }
}
