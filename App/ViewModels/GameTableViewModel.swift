import Foundation
import Observation
import SixthSeat

/// Observable wrapper around `GameState`. Bridges UI intent to engine
/// actions and exposes the state the game-table screen renders from.
///
/// Uses `InMemoryChipStore` for the session-7 prototype — persistence
/// will be wired in a later session.
@Observable
final class GameTableViewModel {

    // MARK: - UI-facing state

    private(set) var phase: GamePhase
    private(set) var chipBalance: Int
    private(set) var anteBet: Int
    private(set) var blindBet: Int
    private(set) var tripsBet: Int
    private(set) var playBet: Int
    private(set) var playerHoleCards: [Card]
    private(set) var dealerHoleCards: [Card]
    private(set) var communityCards: [Card]
    private(set) var lastHandResult: HandResult?
    private(set) var errorMessage: String?

    /// Current ante wager selected in the pre-deal stake picker.
    /// Only meaningful while `phase == .awaitingBets`.
    var stagedAnte: Int

    /// Currently staged Trips side bet (0 = off). Committed to the engine
    /// via `placeTrips` when the player taps DEAL.
    private(set) var stagedTrips: Int

    // MARK: - Dependencies

    private let game: GameState
    private let chipStore: ChipStoreProtocol

    /// Default ante increments the player can cycle through with +/-.
    let anteSteps: [Int] = [5, 10, 25, 50, 100, 250, 500, 1000]

    /// Amounts the Trips zone cycles through on tap. Zero represents "off".
    let tripsCycle: [Int] = [0, 5, 10, 25]

    // MARK: - Init

    init(chipStore: ChipStoreProtocol? = nil) {
        let store = chipStore ?? InMemoryChipStore()
        // Grant starter bonus on first run — matches the production path
        // once UserDefaults persistence is wired in later.
        BonusLogic.applyStarterBonusIfEligible(store: store)
        self.chipStore = store
        self.game = GameState(chipStore: store)

        self.phase = .awaitingBets
        self.chipBalance = store.chipBalance
        self.anteBet = 0
        self.blindBet = 0
        self.tripsBet = 0
        self.playBet = 0
        self.playerHoleCards = []
        self.dealerHoleCards = []
        self.communityCards = []
        self.lastHandResult = nil
        self.errorMessage = nil
        self.stagedAnte = 10
        self.stagedTrips = 0
    }

    // MARK: - Derived display helpers

    var formattedBalance: String {
        Self.currencyFormatter.string(from: NSNumber(value: chipBalance)) ?? "$\(chipBalance)"
    }

    var phaseLabel: String {
        switch phase {
        case .awaitingBets:     return "Place your bets"
        case .preFlopDecision:  return "Pre-flop: Check or Bet"
        case .postFlopDecision: return "Post-flop: Check or Bet"
        case .postRiverDecision: return "River: Fold or Bet"
        case .resolving:        return "Resolving hand…"
        case .handComplete:     return "Hand complete"
        }
    }

    var dealerCardsFaceDown: Bool {
        // Reveal dealer cards once the hand is being/has been resolved.
        phase != .handComplete
    }

    var canDeal: Bool {
        phase == .awaitingBets && anteBet > 0
    }

    /// Trips amount to render in the Trips bet zone. While placing bets we
    /// show the staged value; once committed by `deal`, we show the engine
    /// value (which stays put until the hand resolves and resets).
    var displayedTripsBet: Int {
        phase == .awaitingBets ? stagedTrips : tripsBet
    }

    /// Whether the Trips zone should be interactive. Only true while the
    /// player is placing bets — once DEAL fires, the zone locks.
    var isTripsZoneInteractive: Bool {
        phase == .awaitingBets
    }

    // MARK: - Intent handlers

    func incrementStagedAnte() {
        if let idx = anteSteps.firstIndex(of: stagedAnte), idx + 1 < anteSteps.count {
            stagedAnte = anteSteps[idx + 1]
        } else if !anteSteps.contains(stagedAnte) {
            stagedAnte = anteSteps.first(where: { $0 > stagedAnte }) ?? stagedAnte
        }
    }

    func decrementStagedAnte() {
        if let idx = anteSteps.firstIndex(of: stagedAnte), idx > 0 {
            stagedAnte = anteSteps[idx - 1]
        } else if !anteSteps.contains(stagedAnte) {
            stagedAnte = anteSteps.last(where: { $0 < stagedAnte }) ?? stagedAnte
        }
    }

    func placeAnte(amount: Int) {
        dispatch(.placeAnte(amount: amount))
    }

    /// Advances the Trips side bet through off → $5 → $10 → $25 → off.
    /// Unaffordable steps fall back to "off" so we never hit an engine
    /// error mid-cycle. No-op outside `.awaitingBets`.
    func cycleTripsBet() {
        guard phase == .awaitingBets else { return }
        let currentIndex = tripsCycle.firstIndex(of: stagedTrips) ?? 0
        let nextIndex = (currentIndex + 1) % tripsCycle.count
        let next = tripsCycle[nextIndex]
        stagedTrips = (next == 0 || chipBalance >= next) ? next : 0
    }

    /// Commits the staged ante (and Trips, if any) and immediately deals.
    func deal() {
        if anteBet != stagedAnte {
            dispatch(.placeAnte(amount: stagedAnte))
            // If placing the ante failed we stop here.
            guard errorMessage == nil else { return }
        }
        if stagedTrips > 0 && tripsBet != stagedTrips {
            dispatch(.placeTrips(amount: stagedTrips))
            guard errorMessage == nil else { return }
        }
        dispatch(.deal)
    }

    func betPreFlop(multiplier: Int) {
        dispatch(.betPreFlop(multiplier: multiplier))
    }

    func checkPreFlop() {
        dispatch(.checkPreFlop)
    }

    func betPostFlop() {
        dispatch(.betPostFlop)
    }

    func checkPostFlop() {
        dispatch(.checkPostFlop)
    }

    func betPostRiver() {
        dispatch(.betPostRiver)
    }

    func fold() {
        dispatch(.fold)
    }

    func newHand() {
        dispatch(.collectAndReset)
        stagedTrips = 0
    }

    // MARK: - Dispatch + sync

    private func dispatch(_ action: PlayerAction) {
        errorMessage = nil
        let result = game.perform(action)
        if case .failure(let error) = result {
            errorMessage = describe(error)
        }
        syncFromGame()
    }

    private func syncFromGame() {
        phase = game.phase
        chipBalance = game.chipBalance
        anteBet = game.anteBet
        blindBet = game.blindBet
        tripsBet = game.tripsBet
        playBet = game.playBet
        playerHoleCards = game.playerHoleCards
        dealerHoleCards = game.dealerHoleCards
        communityCards = game.communityCards
        lastHandResult = game.lastHandResult
    }

    private func describe(_ error: GameError) -> String {
        switch error {
        case .illegalActionForPhase:
            return "That action isn't allowed right now."
        case .insufficientChips(let required, let available):
            return "Need \(required) chips — you have \(available)."
        case .invalidBetAmount(let reason):
            return reason
        case .invalidMultiplier(let given, let allowed):
            return "Bet \(given)× not allowed. Use \(allowed.map(String.init).joined(separator: " or "))×."
        }
    }

    // MARK: - Formatting

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()
}
