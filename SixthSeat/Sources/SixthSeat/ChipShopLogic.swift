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

    /// Restore-completed status string for the bottom-row affordance.
    public static func restoreMessage(restoredCount: Int) -> String {
        if restoredCount == 0 {
            return "No purchases to restore."
        }
        let noun = restoredCount == 1 ? "purchase" : "purchases"
        return "Restored \(restoredCount) \(noun)."
    }
}
