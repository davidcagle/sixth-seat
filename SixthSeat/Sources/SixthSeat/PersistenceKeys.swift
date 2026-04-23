import Foundation

/// Namespaced UserDefaults keys for persisted game state. Kept as string
/// constants in one place to prevent accidental collisions with other
/// UserDefaults users on the device.
public enum PersistenceKeys {
    public static let chipBalance = "com.sixthseat.uth.chipBalance"
    public static let hasReceivedStarterBonus = "com.sixthseat.uth.starterBonus"
    public static let hasReceivedSecondChanceBonus = "com.sixthseat.uth.secondChanceBonus"
    public static let totalHandsPlayed = "com.sixthseat.uth.totalHandsPlayed"
}
