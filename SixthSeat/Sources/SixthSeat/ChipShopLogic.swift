import Foundation

/// Pure helpers backing the Chip Shop UI. Extracted so the chip-amount
/// formatting and restore-message behavior are unit-testable without
/// rendering SwiftUI.
public enum ChipShopLogic {

    /// Format a chip count for tile display. Matches the menu's
    /// thousands-separated style without a currency symbol — chips,
    /// not dollars.
    public static func formatChipAmount(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Cause-specific inline failure line for a tier whose purchase
    /// failed. Each `IAPError` maps to actionable copy so the player
    /// knows whether to retry, check connectivity, fix their App Store
    /// sign-in, or change payment — instead of the old one-size-fits-all
    /// "Purchase failed. Try again." `unknown` embeds the underlying
    /// StoreKit description so even unmapped failures say something
    /// concrete. `userCancelled` never reaches here — the view model
    /// treats it as a silent no-op.
    public static func purchaseFailureMessage(for error: IAPError) -> String {
        switch error {
        case .notEntitled:
            return "You're not signed into the App Store. Check Settings → App Store."
        case .productUnavailable, .productNotFound:
            return "This chip pack is temporarily unavailable. Try again in a few minutes."
        case .networkError:
            return "No internet connection. Check your connection and try again."
        case .paymentNotAllowed:
            return "Purchases are restricted on this device (parental controls)."
        case .paymentInvalid:
            return "Your payment method was declined. Update payment in Settings → App Store."
        case .verificationFailed:
            return "Purchase failed: the transaction couldn't be verified. Try again."
        case .unknown(let description):
            return "Purchase failed: \(description). Try again."
        }
    }

    /// Restore-completed status string for the bottom-row affordance.
    public static func restoreMessage(restoredCount: Int) -> String {
        if restoredCount == 0 {
            return "No purchases to restore."
        }
        let noun = restoredCount == 1 ? "purchase" : "purchases"
        return "Restored \(restoredCount) \(noun)."
    }
}
