import Foundation
import Testing
@testable import SixthSeat

@Suite("ChipShopLogic")
struct ChipShopLogicTests {

    @Test("formatChipAmount adds thousands separators with no decimal portion")
    func formatChipAmount() {
        #expect(ChipShopLogic.formatChipAmount(0) == "0")
        #expect(ChipShopLogic.formatChipAmount(5_000) == "5,000")
        #expect(ChipShopLogic.formatChipAmount(750_000) == "750,000")
        #expect(ChipShopLogic.formatChipAmount(1_500_000) == "1,500,000")
    }

    @Test("restoreMessage uses singular vs plural correctly and a quiet zero string")
    func restoreMessages() {
        #expect(ChipShopLogic.restoreMessage(restoredCount: 0) == "No purchases to restore.")
        #expect(ChipShopLogic.restoreMessage(restoredCount: 1) == "Restored 1 purchase.")
        #expect(ChipShopLogic.restoreMessage(restoredCount: 4) == "Restored 4 purchases.")
    }

    @Test("purchaseFailureMessage maps each IAPError to its own actionable line")
    func purchaseFailureMessages() {
        #expect(ChipShopLogic.purchaseFailureMessage(for: .notEntitled)
            == "You're not signed into the App Store. Check Settings → App Store.")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .productUnavailable)
            == "This chip pack is temporarily unavailable. Try again in a few minutes.")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .productNotFound)
            == "This chip pack is temporarily unavailable. Try again in a few minutes.")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .networkError)
            == "No internet connection. Check your connection and try again.")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .paymentNotAllowed)
            == "Purchases are restricted on this device (parental controls).")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .paymentInvalid)
            == "Your payment method was declined. Update payment in Settings → App Store.")
        #expect(ChipShopLogic.purchaseFailureMessage(for: .verificationFailed)
            == "Purchase failed: the transaction couldn't be verified. Try again.")
    }

    @Test("purchaseFailureMessage embeds the underlying description for unknown errors")
    func purchaseFailureUnknownEmbedsDescription() {
        let message = ChipShopLogic.purchaseFailureMessage(for: .unknown("Payment Sheet dismissed"))
        #expect(message == "Purchase failed: Payment Sheet dismissed. Try again.")
    }

    @Test("IAPError.telemetryType is a stable low-cardinality token per case")
    func telemetryTypeTokens() {
        #expect(IAPError.productNotFound.telemetryType == "productNotFound")
        #expect(IAPError.productUnavailable.telemetryType == "productUnavailable")
        #expect(IAPError.notEntitled.telemetryType == "notEntitled")
        #expect(IAPError.paymentNotAllowed.telemetryType == "paymentNotAllowed")
        #expect(IAPError.paymentInvalid.telemetryType == "paymentInvalid")
        #expect(IAPError.networkError.telemetryType == "networkError")
        #expect(IAPError.verificationFailed.telemetryType == "verificationFailed")
        // The associated value does not leak into the type token.
        #expect(IAPError.unknown("anything").telemetryType == "unknown")
    }
}
