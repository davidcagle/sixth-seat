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
}
