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

    /// Set of `Transaction.id` strings that have already credited chips on
    /// this install. The IAP credit path consults this set as its first
    /// guard — a transaction whose id is already present is a no-op,
    /// preventing double-credit on listener replay, restore re-emission,
    /// or Family Sharing redelivery. (Session 16)
    var processedTransactionIDs: Set<String> { get set }

    /// Applies a signed balance delta as one synchronized operation.
    /// Returns `false` without changing the balance when the adjustment
    /// would make it negative.
    @discardableResult
    func adjustChipBalance(by delta: Int) -> Bool

    /// Atomically deduplicates and credits an App Store transaction.
    /// Returns `false` when `transactionID` was already processed.
    @discardableResult
    func creditPurchase(transactionID: String, amount: Int) -> Bool

    /// Clears every stored value back to defaults. Intended for tests
    /// and development tools — not for use in the shipping UI.
    func reset()
}

/// Production implementation backed by `UserDefaults`.
public final class UserDefaultsChipStore: ChipStoreProtocol, @unchecked Sendable {

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Apply the starter bonus eagerly so the first thing the player
        // sees on the Main Menu is their 5,000-chip bankroll, not zero.
        // Lazy application at game-entry leaks zero through the menu and
        // collides with the second-chance bonus trigger, stacking both.
        BonusLogic.applyStarterBonusIfEligible(store: self)
    }

    public var chipBalance: Int {
        get { lock.withLock { readEconomyState().balance } }
        set {
            lock.withLock {
                let state = readEconomyState()
                writeEconomyState(balance: newValue, transactionIDs: state.transactionIDs)
            }
        }
    }

    public var hasReceivedStarterBonus: Bool {
        get { lock.withLock { defaults.bool(forKey: PersistenceKeys.hasReceivedStarterBonus) } }
        set { lock.withLock { defaults.set(newValue, forKey: PersistenceKeys.hasReceivedStarterBonus) } }
    }

    public var hasReceivedSecondChanceBonus: Bool {
        get { lock.withLock { defaults.bool(forKey: PersistenceKeys.hasReceivedSecondChanceBonus) } }
        set { lock.withLock { defaults.set(newValue, forKey: PersistenceKeys.hasReceivedSecondChanceBonus) } }
    }

    public var totalHandsPlayed: Int {
        get { lock.withLock { defaults.integer(forKey: PersistenceKeys.totalHandsPlayed) } }
        set { lock.withLock { defaults.set(newValue, forKey: PersistenceKeys.totalHandsPlayed) } }
    }

    public var processedTransactionIDs: Set<String> {
        get { lock.withLock { readEconomyState().transactionIDs } }
        set {
            // Sort on write so the underlying array is stable across writes —
            // makes the persisted shape diff-friendly when inspecting plists
            // and avoids spurious "value changed" KVO callbacks if Apple
            // ever adds plist-equality observation.
            lock.withLock {
                let state = readEconomyState()
                writeEconomyState(balance: state.balance, transactionIDs: newValue)
            }
        }
    }

    public func adjustChipBalance(by delta: Int) -> Bool {
        lock.withLock {
            let state = readEconomyState()
            let updated = state.balance + delta
            guard updated >= 0 else { return false }
            writeEconomyState(balance: updated, transactionIDs: state.transactionIDs)
            return true
        }
    }

    public func creditPurchase(transactionID: String, amount: Int) -> Bool {
        lock.withLock {
            let state = readEconomyState()
            guard !state.transactionIDs.contains(transactionID) else { return false }
            let updatedBalance = state.balance + amount
            guard updatedBalance >= 0 else { return false }
            var ids = state.transactionIDs
            ids.insert(transactionID)
            writeEconomyState(balance: updatedBalance, transactionIDs: ids)
            return true
        }
    }

    private func readEconomyState() -> (balance: Int, transactionIDs: Set<String>) {
        if let state = defaults.dictionary(forKey: PersistenceKeys.economyState),
           let balance = state["balance"] as? Int,
           let transactionIDs = state["processedTransactionIDs"] as? [String] {
            return (balance, Set(transactionIDs))
        }

        // One-time compatibility path for installs created before the
        // combined economy value existed. The next mutation persists the
        // migrated state under `economyState`.
        let legacyBalance = defaults.integer(forKey: PersistenceKeys.chipBalance)
        let legacyIDs = defaults.array(forKey: PersistenceKeys.processedTransactionIDs) as? [String] ?? []
        return (legacyBalance, Set(legacyIDs))
    }

    private func writeEconomyState(balance: Int, transactionIDs: Set<String>) {
        defaults.set(
            [
                "balance": balance,
                "processedTransactionIDs": Array(transactionIDs).sorted()
            ],
            forKey: PersistenceKeys.economyState
        )
    }

    public func reset() {
        lock.withLock {
            defaults.removeObject(forKey: PersistenceKeys.chipBalance)
            defaults.removeObject(forKey: PersistenceKeys.economyState)
            defaults.removeObject(forKey: PersistenceKeys.hasReceivedStarterBonus)
            defaults.removeObject(forKey: PersistenceKeys.hasReceivedSecondChanceBonus)
            defaults.removeObject(forKey: PersistenceKeys.totalHandsPlayed)
            defaults.removeObject(forKey: PersistenceKeys.processedTransactionIDs)
        }
    }
}

/// Test double that stores values in memory without touching
/// UserDefaults. Tests MUST use this to avoid leaking state between
/// runs or into the real user's defaults database.
public final class InMemoryChipStore: ChipStoreProtocol, @unchecked Sendable {

    private let lock = NSRecursiveLock()
    private var storedChipBalance: Int
    private var storedHasReceivedStarterBonus: Bool
    private var storedHasReceivedSecondChanceBonus: Bool
    private var storedTotalHandsPlayed: Int
    private var storedProcessedTransactionIDs: Set<String>

    public var chipBalance: Int {
        get { lock.withLock { storedChipBalance } }
        set { lock.withLock { storedChipBalance = newValue } }
    }
    public var hasReceivedStarterBonus: Bool {
        get { lock.withLock { storedHasReceivedStarterBonus } }
        set { lock.withLock { storedHasReceivedStarterBonus = newValue } }
    }
    public var hasReceivedSecondChanceBonus: Bool {
        get { lock.withLock { storedHasReceivedSecondChanceBonus } }
        set { lock.withLock { storedHasReceivedSecondChanceBonus = newValue } }
    }
    public var totalHandsPlayed: Int {
        get { lock.withLock { storedTotalHandsPlayed } }
        set { lock.withLock { storedTotalHandsPlayed = newValue } }
    }
    public var processedTransactionIDs: Set<String> {
        get { lock.withLock { storedProcessedTransactionIDs } }
        set { lock.withLock { storedProcessedTransactionIDs = newValue } }
    }

    public init(
        chipBalance: Int = 0,
        hasReceivedStarterBonus: Bool = false,
        hasReceivedSecondChanceBonus: Bool = false,
        totalHandsPlayed: Int = 0,
        processedTransactionIDs: Set<String> = []
    ) {
        self.storedChipBalance = chipBalance
        self.storedHasReceivedStarterBonus = hasReceivedStarterBonus
        self.storedHasReceivedSecondChanceBonus = hasReceivedSecondChanceBonus
        self.storedTotalHandsPlayed = totalHandsPlayed
        self.storedProcessedTransactionIDs = processedTransactionIDs
    }

    public func adjustChipBalance(by delta: Int) -> Bool {
        lock.withLock {
            let updated = storedChipBalance + delta
            guard updated >= 0 else { return false }
            storedChipBalance = updated
            return true
        }
    }

    public func creditPurchase(transactionID: String, amount: Int) -> Bool {
        lock.withLock {
            guard !storedProcessedTransactionIDs.contains(transactionID) else { return false }
            guard adjustChipBalance(by: amount) else { return false }
            storedProcessedTransactionIDs.insert(transactionID)
            return true
        }
    }

    public func reset() {
        lock.withLock {
            storedChipBalance = 0
            storedHasReceivedStarterBonus = false
            storedHasReceivedSecondChanceBonus = false
            storedTotalHandsPlayed = 0
            storedProcessedTransactionIDs = []
        }
    }
}
