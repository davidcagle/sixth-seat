import Foundation

/// Namespaced UserDefaults keys for persisted game state. Kept as string
/// constants in one place to prevent accidental collisions with other
/// UserDefaults users on the device.
public enum PersistenceKeys {
    public static let chipBalance = "com.sixthseat.uth.chipBalance"
    public static let hasReceivedStarterBonus = "com.sixthseat.uth.starterBonus"
    public static let hasReceivedSecondChanceBonus = "com.sixthseat.uth.secondChanceBonus"
    public static let totalHandsPlayed = "com.sixthseat.uth.totalHandsPlayed"

    /// True once the player has acknowledged the first-launch Apple 4.3
    /// simulated-gambling disclosure. Gates the disclosure modal presentation.
    public static let hasSeenDisclosure = "com.sixthseat.uth.hasSeenDisclosure"

    /// `@AppStorage`-backed user preferences. Read at the call site (audio
    /// engine, haptics service) so a flag flip in Settings takes effect
    /// without restarting. Defaults are "on" — UserDefaults returns false
    /// for unset bool keys, so reads must default-to-true on absence.
    public static let settingsSFXEnabled = "com.sixthseat.uth.settings.sfxEnabled"
    public static let settingsAmbientEnabled = "com.sixthseat.uth.settings.ambientEnabled"
    public static let settingsHapticsEnabled = "com.sixthseat.uth.settings.hapticsEnabled"
}
