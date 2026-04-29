import Foundation

/// Persistence boundary for the player's chip balance, one-time bonus
/// flags, and IAP idempotency state. Keeping this behind a protocol lets
/// us swap UserDefaults for CloudKit later (V2 multiplayer / cross-device
/// chip carry) without rewriting `GameState` or the IAP service.
///
/// Marked `Sendable` so the IAP service (which may run on a background
/// task driven by `Transaction.updates`) can mutate the store from a
/// non-main isolation domain. Production and test implementations are
/// `@unchecked Sendable` because UserDefaults is documented thread-safe
/// and the in-memory test double is exercised serially.
public protocol ChipStoreProtocol: AnyObject, Sendable {
    var chipBalance: Int { get set }
    var hasReceivedStarterBonus: Bool { get set }
    var hasReceivedSecondChanceBonus: Bool { get set }
    var totalHandsPlayed: Int { get set }

    /// Per-install first-purchase doubler flag. `false` on a fresh install;
    /// flipped to `true` by `ChipPurchaseProcessor.credit` *before* chips
    /// are credited so a force-quit during the credit step can't replay
    /// the doubler on next launch. (Session 16)
    var hasMadeFirstPurchase: Bool { get set }

    /// Set of `Transaction.id` strings that have already credited chips on
    /// this install. The IAP credit path consults this set as its first
    /// guard — a transaction whose id is already present is a no-op,
    /// preventing double-credit on listener replay, restore re-emission,
    /// or Family Sharing redelivery. (Session 16)
    var processedTransactionIDs: Set<String> { get set }

    /// Clears every stored value back to defaults. Intended for tests
    /// and development tools — not for use in the shipping UI.
    func reset()
}

/// Production implementation backed by `UserDefaults`.
public final class UserDefaultsChipStore: ChipStoreProtocol, @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Apply the starter bonus eagerly so the first thing the player
        // sees on the Main Menu is their 5,000-chip bankroll, not zero.
        // Lazy application at game-entry leaks zero through the menu and
        // collides with the second-chance bonus trigger, stacking both.
        BonusLogic.applyStarterBonusIfEligible(store: self)
    }

    public var chipBalance: Int {
        get { defaults.integer(forKey: PersistenceKeys.chipBalance) }
        set { defaults.set(newValue, forKey: PersistenceKeys.chipBalance) }
    }

    public var hasReceivedStarterBonus: Bool {
        get { defaults.bool(forKey: PersistenceKeys.hasReceivedStarterBonus) }
        set { defaults.set(newValue, forKey: PersistenceKeys.hasReceivedStarterBonus) }
    }

    public var hasReceivedSecondChanceBonus: Bool {
        get { defaults.bool(forKey: PersistenceKeys.hasReceivedSecondChanceBonus) }
        set { defaults.set(newValue, forKey: PersistenceKeys.hasReceivedSecondChanceBonus) }
    }

    public var totalHandsPlayed: Int {
        get { defaults.integer(forKey: PersistenceKeys.totalHandsPlayed) }
        set { defaults.set(newValue, forKey: PersistenceKeys.totalHandsPlayed) }
    }

    public var hasMadeFirstPurchase: Bool {
        get { defaults.bool(forKey: PersistenceKeys.hasMadeFirstPurchase) }
        set { defaults.set(newValue, forKey: PersistenceKeys.hasMadeFirstPurchase) }
    }

    public var processedTransactionIDs: Set<String> {
        get {
            let array = defaults.array(forKey: PersistenceKeys.processedTransactionIDs) as? [String] ?? []
            return Set(array)
        }
        set {
            // Sort on write so the underlying array is stable across writes —
            // makes the persisted shape diff-friendly when inspecting plists
            // and avoids spurious "value changed" KVO callbacks if Apple
            // ever adds plist-equality observation.
            defaults.set(Array(newValue).sorted(), forKey: PersistenceKeys.processedTransactionIDs)
        }
    }

    public func reset() {
        defaults.removeObject(forKey: PersistenceKeys.chipBalance)
        defaults.removeObject(forKey: PersistenceKeys.hasReceivedStarterBonus)
        defaults.removeObject(forKey: PersistenceKeys.hasReceivedSecondChanceBonus)
        defaults.removeObject(forKey: PersistenceKeys.totalHandsPlayed)
        defaults.removeObject(forKey: PersistenceKeys.hasMadeFirstPurchase)
        defaults.removeObject(forKey: PersistenceKeys.processedTransactionIDs)
    }
}

/// Test double that stores values in memory without touching
/// UserDefaults. Tests MUST use this to avoid leaking state between
/// runs or into the real user's defaults database.
public final class InMemoryChipStore: ChipStoreProtocol, @unchecked Sendable {

    public var chipBalance: Int
    public var hasReceivedStarterBonus: Bool
    public var hasReceivedSecondChanceBonus: Bool
    public var totalHandsPlayed: Int
    public var hasMadeFirstPurchase: Bool
    public var processedTransactionIDs: Set<String>

    public init(
        chipBalance: Int = 0,
        hasReceivedStarterBonus: Bool = false,
        hasReceivedSecondChanceBonus: Bool = false,
        totalHandsPlayed: Int = 0,
        hasMadeFirstPurchase: Bool = false,
        processedTransactionIDs: Set<String> = []
    ) {
        self.chipBalance = chipBalance
        self.hasReceivedStarterBonus = hasReceivedStarterBonus
        self.hasReceivedSecondChanceBonus = hasReceivedSecondChanceBonus
        self.totalHandsPlayed = totalHandsPlayed
        self.hasMadeFirstPurchase = hasMadeFirstPurchase
        self.processedTransactionIDs = processedTransactionIDs
    }

    public func reset() {
        chipBalance = 0
        hasReceivedStarterBonus = false
        hasReceivedSecondChanceBonus = false
        totalHandsPlayed = 0
        hasMadeFirstPurchase = false
        processedTransactionIDs = []
    }
}
