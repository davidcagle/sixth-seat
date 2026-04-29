import Foundation
import Testing
@testable import SixthSeat

@Suite("ChipShopLogic")
struct ChipShopLogicTests {

    private let bundle = ChipBundle(
        id: "id",
        displayName: "Bundle",
        chipAmount: 5_000,
        localizedPrice: "$0.99"
    )

    @Test("Doubler is active when the player has not yet made a first purchase")
    func doublerActiveBeforeFirstPurchase() {
        #expect(ChipShopLogic.doublerActive(hasMadeFirstPurchase: false) == true)
        #expect(ChipShopLogic.doublerActive(hasMadeFirstPurchase: true) == false)
    }

    @Test("displayAmount doubles the bundle amount while the doubler is active")
    func displayAmountWithDoubler() {
        #expect(ChipShopLogic.displayAmount(for: bundle, doublerActive: true) == 10_000)
        #expect(ChipShopLogic.displayAmount(for: bundle, doublerActive: false) == 5_000)
    }

    @Test("strikethroughAmount returns the base amount only while the doubler is active")
    func strikethroughOnlyWhileDoubled() {
        #expect(ChipShopLogic.strikethroughAmount(for: bundle, doublerActive: true) == 5_000)
        #expect(ChipShopLogic.strikethroughAmount(for: bundle, doublerActive: false) == nil)
    }

    @Test("formatChipAmount adds thousands separators with no decimal portion")
    func formatChipAmount() {
        #expect(ChipShopLogic.formatChipAmount(0) == "0")
        #expect(ChipShopLogic.formatChipAmount(5_000) == "5,000")
        #expect(ChipShopLogic.formatChipAmount(750_000) == "750,000")
        #expect(ChipShopLogic.formatChipAmount(1_500_000) == "1,500,000")
    }

    @Test("Banner copy is the contracted 2X CHIPS string")
    func bannerCopy() {
        #expect(ChipShopLogic.bannerText == "2X CHIPS ON YOUR FIRST PURCHASE")
    }

    @Test("restoreMessage uses singular vs plural correctly and a quiet zero string")
    func restoreMessages() {
        #expect(ChipShopLogic.restoreMessage(restoredCount: 0) == "No purchases to restore.")
        #expect(ChipShopLogic.restoreMessage(restoredCount: 1) == "Restored 1 purchase.")
        #expect(ChipShopLogic.restoreMessage(restoredCount: 4) == "Restored 4 purchases.")
    }
}
