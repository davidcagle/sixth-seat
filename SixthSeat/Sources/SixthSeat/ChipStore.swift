import Foundation

/// Persistence boundary for the player's chip balance and one-time
/// bonus flags. Keeping this behind a protocol lets us swap
/// UserDefaults for CloudKit later (V2 multiplayer) without rewriting
/// `GameState`.
public protocol ChipStoreProtocol: AnyObject {
    var chipBalance: Int { get set }
    var hasReceivedStarterBonus: Bool { get set }
    var hasReceivedSecondChanceBonus: Bool { get set }
    var totalHandsPlayed: Int { get set }

    /// Clears every stored value back to defaults. Intended for tests
    /// and development tools — not for use in the shipping UI.
    func reset()
}

/// Production implementation backed by `UserDefaults`.
public final class UserDefaultsChipStore: ChipStoreProtocol {

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

    public func reset() {
        defaults.removeObject(forKey: PersistenceKeys.chipBalance)
        defaults.removeObject(forKey: PersistenceKeys.hasReceivedStarterBonus)
        defaults.removeObject(forKey: PersistenceKeys.hasReceivedSecondChanceBonus)
        defaults.removeObject(forKey: PersistenceKeys.totalHandsPlayed)
    }
}

/// Test double that stores values in memory without touching
/// UserDefaults. Tests MUST use this to avoid leaking state between
/// runs or into the real user's defaults database.
public final class InMemoryChipStore: ChipStoreProtocol {

    public var chipBalance: Int
    public var hasReceivedStarterBonus: Bool
    public var hasReceivedSecondChanceBonus: Bool
    public var totalHandsPlayed: Int

    public init(
        chipBalance: Int = 0,
        hasReceivedStarterBonus: Bool = false,
        hasReceivedSecondChanceBonus: Bool = false,
        totalHandsPlayed: Int = 0
    ) {
        self.chipBalance = chipBalance
        self.hasReceivedStarterBonus = hasReceivedStarterBonus
        self.hasReceivedSecondChanceBonus = hasReceivedSecondChanceBonus
        self.totalHandsPlayed = totalHandsPlayed
    }

    public func reset() {
        chipBalance = 0
        hasReceivedStarterBonus = false
        hasReceivedSecondChanceBonus = false
        totalHandsPlayed = 0
    }
}
