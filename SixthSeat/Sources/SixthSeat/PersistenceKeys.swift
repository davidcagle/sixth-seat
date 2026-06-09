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
    /// service, haptics service) so a flag flip in Settings takes effect
    /// without restarting. Defaults are "on" — UserDefaults returns false
    /// for unset bool keys, so reads must default-to-true on absence.
    ///
    /// `settingsAmbientEnabled` (the "Music" / "Ambient Audio" toggle) was
    /// removed in Session 19a along with the toggle itself; no music asset
    /// was sourced for V1, so the key had nothing to gate. Music returns
    /// as a V2 candidate.
    public static let settingsSFXEnabled = "com.sixthseat.uth.settings.sfxEnabled"
    public static let settingsHapticsEnabled = "com.sixthseat.uth.settings.hapticsEnabled"

    /// Last-played `TableConfig.id`. Set on tap from the table-select
    /// screen, read on next visit to render the "Last played" badge.
    /// Default-handling lives in `TableConfig.table(forID:)` — an unset
    /// or unknown id resolves to `TableConfig.defaultTable`. (Session 15b)
    public static let selectedTableID = "com.sixthseat.uth.settings.selectedTableID"

    /// JSON-encoded array (stored as `[String]` via UserDefaults) of every
    /// `Transaction.id` that has already credited chips on this install.
    /// Guards the credit path against double-crediting on listener replay,
    /// restore-purchases re-emission, or Family Sharing redelivery.
    /// Idempotency is the load-bearing IAP invariant: a given transaction
    /// MUST NOT credit twice. (Session 16)
    public static let processedTransactionIDs = "com.sixthseat.uth.iap.processedTransactionIDs"
}
