import Foundation

/// The two one-time chip bonuses described in the PDR.
///
/// - **Starter bonus**: 5,000 chips granted on first launch.
/// - **Second-chance bonus**: 2,500 chips granted the first time the
///   player busts out to a zero balance.
public enum BonusLogic {

    public static let starterBonusAmount = 5_000
    public static let secondChanceBonusAmount = 2_500

    /// Grants the starter bonus if it has not been granted before.
    /// - Returns: `true` if chips were added on this call.
    @discardableResult
    public static func applyStarterBonusIfEligible(store: ChipStoreProtocol) -> Bool {
        guard !store.hasReceivedStarterBonus else { return false }
        store.chipBalance += starterBonusAmount
        store.hasReceivedStarterBonus = true
        return true
    }

    /// Grants the second-chance bonus when the player is functionally
    /// bust — balance below `GameConstants.minimumPlayableBalance` (the
    /// cheapest table's `minimumEntryBalance`, i.e. no V1 table is
    /// enterable) — and has not yet received this bonus.
    /// - Returns: `true` if chips were added on this call.
    @discardableResult
    public static func applySecondChanceBonusIfEligible(store: ChipStoreProtocol) -> Bool {
        guard store.chipBalance < GameConstants.minimumPlayableBalance,
              !store.hasReceivedSecondChanceBonus else {
            return false
        }
        store.chipBalance += secondChanceBonusAmount
        store.hasReceivedSecondChanceBonus = true
        return true
    }
}
