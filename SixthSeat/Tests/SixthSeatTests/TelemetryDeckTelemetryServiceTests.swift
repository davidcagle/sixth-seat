import Foundation
import Testing
@testable import SixthSeat

@Suite("TelemetryDeckTelemetryService payload shape (Session 19b)")
struct TelemetryDeckTelemetryServiceTests {

    // MARK: - IAP payload shape

    @Test("purchase.succeeded carries product_id and the tier's chip_amount")
    func purchaseSucceededPayloadShape() {
        let bundle = ChipBundleCatalog.starter
        let params = TelemetryDeckTelemetryService.purchaseSucceededParameters(
            productID: bundle.id
        )
        #expect(params["product_id"] == bundle.id)
        #expect(params["chip_amount"] == String(bundle.chipAmount))
        // Doubler-era params are gone — the payload is just id + amount.
        #expect(params.count == 2)
    }

    @Test("purchase.succeeded returns chip_amount = 0 for an unknown product (defensive fallback)")
    func purchaseSucceededUnknownProductIDFallsBackToZero() {
        let params = TelemetryDeckTelemetryService.purchaseSucceededParameters(
            productID: "com.sixthseat.uth.chips.ghost"
        )
        #expect(params["chip_amount"] == "0")
    }

    @Test("purchase.initiated and purchase.failed carry product_id (plus error_type/error_description for failed)")
    func purchaseInitiatedAndFailedPayloads() {
        let init1 = TelemetryDeckTelemetryService.purchaseInitiatedParameters(productID: "p1")
        #expect(init1 == ["product_id": "p1"])

        let failed = TelemetryDeckTelemetryService.purchaseFailedParameters(
            productID: "p1",
            errorType: "networkError",
            description: "The Internet connection appears to be offline."
        )
        #expect(failed["product_id"] == "p1")
        #expect(failed["error_type"] == "networkError")
        #expect(failed["error_description"] == "The Internet connection appears to be offline.")
        #expect(failed["reason"] == nil) // old param name retired
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
