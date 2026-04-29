import Foundation

/// Pure helpers backing the Chip Shop UI. Extracted so the doubler
/// math, banner visibility, and price/strikethrough behavior are
/// unit-testable without rendering SwiftUI.
public enum ChipShopLogic {

    public static let bannerText = "2X CHIPS ON YOUR FIRST PURCHASE"

    /// True while the per-install first-purchase doubler is still armed.
    /// Drives banner visibility and the per-tile strikethrough on the
    /// base chip amount.
    public static func doublerActive(hasMadeFirstPurchase: Bool) -> Bool {
        !hasMadeFirstPurchase
    }

    /// The chip amount the tile shows as the headline number. Doubled
    /// while the doubler is active; base otherwise.
    public static func displayAmount(for bundle: ChipBundle, doublerActive: Bool) -> Int {
        doublerActive ? bundle.chipAmount * 2 : bundle.chipAmount
    }

    /// The strikethrough number rendered alongside the doubled headline.
    /// Returns `nil` once the doubler has been consumed.
    public static func strikethroughAmount(for bundle: ChipBundle, doublerActive: Bool) -> Int? {
        doublerActive ? bundle.chipAmount : nil
    }

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
