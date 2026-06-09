import Foundation
import TelemetryDeck

/// Production `TelemetryService`: maps each protocol call to a
/// TelemetryDeck signal with a metadata payload.
///
/// `TelemetryDeck.initialize(config:)` must have run before any method
/// here is called. `SixthSeatApp.init` handles that wiring at app
/// launch, ahead of the IAP listener — so background-task IAP
/// completions dispatch to a live SDK.
///
/// The chip amount is derived from `ChipBundleCatalog` at telemetry
/// time rather than threaded through the `purchaseSucceeded` signature —
/// the catalog is the canonical source for what each product ID is
/// worth in chips, so re-deriving it here keeps the protocol surface
/// minimal.
///
/// Signal-name convention (`namespace.event`):
///   - `iap.purchase.initiated`
///   - `iap.purchase.succeeded`
///   - `iap.purchase.failed`
///   - `iap.restore.initiated`
///   - `iap.restore.completed`
///   - `game.hand.resolved`
public struct TelemetryDeckTelemetryService: TelemetryService {

    private let catalog: [ChipBundle]

    /// Snapshots the catalog at construction so chip amounts can be
    /// derived from product IDs on hot paths without reloading.
    public init(catalog: [ChipBundle] = ChipBundleCatalog.all) {
        self.catalog = catalog
    }

    // MARK: - IAP

    public func purchaseInitiated(productID: String) {
        TelemetryDeck.signal(
            Self.purchaseInitiatedSignal,
            parameters: Self.purchaseInitiatedParameters(productID: productID)
        )
    }

    public func purchaseSucceeded(productID: String) {
        TelemetryDeck.signal(
            Self.purchaseSucceededSignal,
            parameters: Self.purchaseSucceededParameters(
                productID: productID,
                catalog: catalog
            )
        )
    }

    public func purchaseFailed(productID: String, reason: String) {
        TelemetryDeck.signal(
            Self.purchaseFailedSignal,
            parameters: Self.purchaseFailedParameters(productID: productID, reason: reason)
        )
    }

    public func restoreInitiated() {
        TelemetryDeck.signal(Self.restoreInitiatedSignal)
    }

    public func restoreCompleted(count: Int) {
        TelemetryDeck.signal(
            Self.restoreCompletedSignal,
            parameters: Self.restoreCompletedParameters(count: count)
        )
    }

    // MARK: - Game

    public func handResolved(
        tableID: String,
        anteAmount: Int,
        tripsAmount: Int,
        resultTone: HandResultTone,
        tripsOutcome: TripsTelemetryOutcome
    ) {
        TelemetryDeck.signal(
            Self.handResolvedSignal,
            parameters: Self.handResolvedParameters(
                tableID: tableID,
                anteAmount: anteAmount,
                tripsAmount: tripsAmount,
                resultTone: resultTone,
                tripsOutcome: tripsOutcome
            )
        )
    }

    // MARK: - Signal names + payload builders (extracted so tests can
    // assert payload shape without intercepting the real SDK)

    public static let purchaseInitiatedSignal = "iap.purchase.initiated"
    public static let purchaseSucceededSignal = "iap.purchase.succeeded"
    public static let purchaseFailedSignal = "iap.purchase.failed"
    public static let restoreInitiatedSignal = "iap.restore.initiated"
    public static let restoreCompletedSignal = "iap.restore.completed"
    public static let handResolvedSignal = "game.hand.resolved"

    public static func purchaseInitiatedParameters(productID: String) -> [String: String] {
        ["product_id": productID]
    }

    public static func purchaseSucceededParameters(
        productID: String,
        catalog: [ChipBundle] = ChipBundleCatalog.all
    ) -> [String: String] {
        return [
            "product_id": productID,
            "chip_amount": String(chipAmount(for: productID, in: catalog))
        ]
    }

    public static func purchaseFailedParameters(productID: String, reason: String) -> [String: String] {
        [
            "product_id": productID,
            "reason": reason
        ]
    }

    public static func restoreCompletedParameters(count: Int) -> [String: String] {
        ["credited_count": String(count)]
    }

    public static func handResolvedParameters(
        tableID: String,
        anteAmount: Int,
        tripsAmount: Int,
        resultTone: HandResultTone,
        tripsOutcome: TripsTelemetryOutcome
    ) -> [String: String] {
        [
            "table_id": tableID,
            "ante_amount": String(anteAmount),
            "trips_amount": String(tripsAmount),
            "result_tone": resultTone.rawValue,
            "trips_outcome": tripsOutcome.rawValue
        ]
    }

    /// Resolves the chip amount for a product ID through the catalog
    /// snapshot. Returns 0 for an unknown ID rather than crashing —
    /// TelemetryDeck would receive `"0"` on the metadata payload and the
    /// unknown-product anomaly would show up in dashboards as a clear
    /// signal rather than a silent crash.
    private static func chipAmount(for productID: String, in catalog: [ChipBundle]) -> Int {
        catalog.first(where: { $0.id == productID })?.chipAmount ?? 0
    }
}
