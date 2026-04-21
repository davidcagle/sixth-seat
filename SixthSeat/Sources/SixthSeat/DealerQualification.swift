import Foundation

/// Ultimate Texas Hold'em dealer-qualification rule.
/// The dealer "qualifies" when their best 5-card hand is a pair or better;
/// if not, the player's Ante pushes regardless of who wins the hand.
public enum DealerQualification {
    public static func qualifies(hand: EvaluatedHand) -> Bool {
        hand.rank >= .pair
    }
}
