import Foundation
import Testing
@testable import SixthSeat

@Suite("TelemetryDeckTelemetryService payload shape (Session 19b)")
struct TelemetryDeckTelemetryServiceTests {

    // MARK: - IAP payload shape

    @Test("purchase.succeeded carries product_id, base + doublered chip amounts, doubler_fired, and is_first_purchase")
    func purchaseSucceededPayloadShape() {
        let bundle = ChipBundleCatalog.starter
        let params = TelemetryDeckTelemetryService.purchaseSucceededParameters(
            productID: bundle.id,
            isFirstPurchase: true
        )
        #expect(params["product_id"] == bundle.id)
        #expect(params["base_chip_amount"] == String(bundle.chipAmount))
        #expect(params["doublered_chip_amount"] == String(bundle.chipAmount * 2))
        #expect(params["doubler_fired"] == "true")
        #expect(params["is_first_purchase"] == "true")
    }

    @Test("purchase.succeeded with isFirstPurchase=false reports doubler_fired=false and base==doublered")
    func purchaseSucceededDoublerDidNotFire() {
        let bundle = ChipBundleCatalog.tableStakes
        let params = TelemetryDeckTelemetryService.purchaseSucceededParameters(
            productID: bundle.id,
            isFirstPurchase: false
        )
        #expect(params["doubler_fired"] == "false")
        #expect(params["is_first_purchase"] == "false")
        #expect(params["base_chip_amount"] == String(bundle.chipAmount))
        #expect(params["doublered_chip_amount"] == String(bundle.chipAmount))
    }

    @Test("purchase.succeeded returns base_chip_amount = 0 for an unknown product (defensive fallback)")
    func purchaseSucceededUnknownProductIDFallsBackToZero() {
        let params = TelemetryDeckTelemetryService.purchaseSucceededParameters(
            productID: "com.sixthseat.uth.chips.ghost",
            isFirstPurchase: false
        )
        #expect(params["base_chip_amount"] == "0")
        #expect(params["doublered_chip_amount"] == "0")
    }

    @Test("purchase.initiated and purchase.failed carry product_id (and reason for failed)")
    func purchaseInitiatedAndFailedPayloads() {
        let init1 = TelemetryDeckTelemetryService.purchaseInitiatedParameters(productID: "p1")
        #expect(init1 == ["product_id": "p1"])

        let failed = TelemetryDeckTelemetryService.purchaseFailedParameters(
            productID: "p1",
            reason: "networkError"
        )
        #expect(failed["product_id"] == "p1")
        #expect(failed["reason"] == "networkError")
    }

    @Test("restore.completed carries credited_count")
    func restoreCompletedPayload() {
        let params = TelemetryDeckTelemetryService.restoreCompletedParameters(count: 3)
        #expect(params == ["credited_count": "3"])
    }

    // MARK: - Hand-resolution payload shape

    @Test("hand.resolved carries table_id, ante_amount, trips_amount, result_tone, trips_outcome")
    func handResolvedPayloadShape() {
        let params = TelemetryDeckTelemetryService.handResolvedParameters(
            tableID: "table_10",
            anteAmount: 25,
            tripsAmount: 10,
            resultTone: .win,
            tripsOutcome: .paid
        )
        #expect(params["table_id"] == "table_10")
        #expect(params["ante_amount"] == "25")
        #expect(params["trips_amount"] == "10")
        #expect(params["result_tone"] == "win")
        #expect(params["trips_outcome"] == "paid")
    }

    @Test("hand.resolved push + no Trips reports trips_amount=0 and trips_outcome=notPlaced")
    func handResolvedPushNoTrips() {
        let params = TelemetryDeckTelemetryService.handResolvedParameters(
            tableID: "table_50",
            anteAmount: 100,
            tripsAmount: 0,
            resultTone: .push,
            tripsOutcome: .notPlaced
        )
        #expect(params["trips_amount"] == "0")
        #expect(params["trips_outcome"] == "notPlaced")
        #expect(params["result_tone"] == "push")
    }

    // MARK: - Signal names

    @Test("Signal names use the iap./game. namespacing convention")
    func signalNamespaces() {
        #expect(TelemetryDeckTelemetryService.purchaseInitiatedSignal == "iap.purchase.initiated")
        #expect(TelemetryDeckTelemetryService.purchaseSucceededSignal == "iap.purchase.succeeded")
        #expect(TelemetryDeckTelemetryService.purchaseFailedSignal == "iap.purchase.failed")
        #expect(TelemetryDeckTelemetryService.restoreInitiatedSignal == "iap.restore.initiated")
        #expect(TelemetryDeckTelemetryService.restoreCompletedSignal == "iap.restore.completed")
        #expect(TelemetryDeckTelemetryService.handResolvedSignal == "game.hand.resolved")
    }
}
