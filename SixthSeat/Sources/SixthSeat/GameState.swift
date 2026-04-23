import Foundation

/// State machine for a single hand of Ultimate Texas Hold'em.
///
/// External code drives the game by calling `perform(_:)` with a
/// `PlayerAction`. Every legal action mutates the relevant state and
/// (when appropriate) advances `phase`; illegal actions return a
/// `GameError` and leave state untouched.
///
/// Chips are deducted from `chipBalance` at the moment a wager is placed
/// and returned (along with winnings) at resolution. The balance lives
/// in an injected `ChipStoreProtocol` so it persists across hands and
/// app launches without this class knowing whether the backing store is
/// UserDefaults, CloudKit, or an in-memory test double.
///
/// `lastHandResult` holds the outcome of the most recently resolved
/// hand and persists through `.handComplete` until `collectAndReset`
/// clears it.
public final class GameState {

    // MARK: - Public state (read-only externally)

    public private(set) var phase: GamePhase
    public private(set) var deck: Deck
    public private(set) var playerHoleCards: [Card]
    public private(set) var communityCards: [Card]
    public private(set) var dealerHoleCards: [Card]
    public private(set) var anteBet: Int
    public private(set) var blindBet: Int
    public private(set) var tripsBet: Int
    public private(set) var playBet: Int
    public private(set) var playerFolded: Bool
    public private(set) var lastHandResult: HandResult?

    /// The player's chip balance, read through from the backing store.
    /// Writes happen internally via `chipStore.chipBalance`.
    public var chipBalance: Int {
        chipStore.chipBalance
    }

    // MARK: - Persistence

    private let chipStore: ChipStoreProtocol

    // MARK: - Init

    public init(chipStore: ChipStoreProtocol) {
        self.chipStore = chipStore
        self.phase = .awaitingBets
        self.deck = Deck()
        self.playerHoleCards = []
        self.communityCards = []
        self.dealerHoleCards = []
        self.anteBet = 0
        self.blindBet = 0
        self.tripsBet = 0
        self.playBet = 0
        self.playerFolded = false
        self.lastHandResult = nil
    }

    /// Production default: uses `UserDefaultsChipStore`, so chip balance
    /// and bonus flags persist across launches.
    public convenience init() {
        self.init(chipStore: UserDefaultsChipStore())
    }

    // MARK: - Action dispatch

    @discardableResult
    public func perform(_ action: PlayerAction) -> Result<Void, GameError> {
        switch (phase, action) {
        case (.awaitingBets, .placeAnte(let amount)):
            return placeAnte(amount: amount)
        case (.awaitingBets, .placeTrips(let amount)):
            return placeTrips(amount: amount)
        case (.awaitingBets, .deal):
            return deal()
        case (.preFlopDecision, .betPreFlop(let multiplier)):
            return betPreFlop(multiplier: multiplier)
        case (.preFlopDecision, .checkPreFlop):
            return checkPreFlop()
        case (.postFlopDecision, .betPostFlop):
            return betPostFlop()
        case (.postFlopDecision, .checkPostFlop):
            return checkPostFlop()
        case (.postRiverDecision, .betPostRiver):
            return betPostRiver()
        case (.postRiverDecision, .fold):
            return fold()
        case (.handComplete, .collectAndReset):
            return collectAndReset()
        default:
            return .failure(.illegalActionForPhase(attempted: action, phase: phase))
        }
    }

    // MARK: - Pre-deal wagers

    private func placeAnte(amount: Int) -> Result<Void, GameError> {
        guard amount > 0 else {
            return .failure(.invalidBetAmount(reason: "Ante must be greater than zero"))
        }
        // Blind always matches Ante, so the player needs 2× the requested amount.
        let required = amount * 2
        // Refund any previously-placed Ante/Blind so the player can adjust the
        // wager up or down before the deal.
        let availableAfterRefund = chipBalance + anteBet + blindBet
        guard availableAfterRefund >= required else {
            return .failure(.insufficientChips(required: required, available: availableAfterRefund))
        }
        chipStore.chipBalance = availableAfterRefund - required
        anteBet = amount
        blindBet = amount
        return .success(())
    }

    private func placeTrips(amount: Int) -> Result<Void, GameError> {
        guard amount > 0 else {
            return .failure(.invalidBetAmount(reason: "Trips must be greater than zero"))
        }
        let availableAfterRefund = chipBalance + tripsBet
        guard availableAfterRefund >= amount else {
            return .failure(.insufficientChips(required: amount, available: availableAfterRefund))
        }
        chipStore.chipBalance = availableAfterRefund - amount
        tripsBet = amount
        return .success(())
    }

    private func deal() -> Result<Void, GameError> {
        guard anteBet > 0 else {
            return .failure(.invalidBetAmount(reason: "Cannot deal without an Ante bet"))
        }
        // 2 hole cards each — interleaved as in a real deal.
        playerHoleCards = [deck.deal()!, deck.deal()!]
        dealerHoleCards = [deck.deal()!, deck.deal()!]
        phase = .preFlopDecision
        return .success(())
    }

    // MARK: - Pre-flop decision

    private func betPreFlop(multiplier: Int) -> Result<Void, GameError> {
        guard multiplier == 3 || multiplier == 4 else {
            return .failure(.invalidMultiplier(given: multiplier, allowed: [3, 4]))
        }
        let required = multiplier * anteBet
        guard chipBalance >= required else {
            return .failure(.insufficientChips(required: required, available: chipBalance))
        }
        chipStore.chipBalance -= required
        playBet = required
        dealCommunity(count: 5)
        resolve()
        return .success(())
    }

    private func checkPreFlop() -> Result<Void, GameError> {
        dealCommunity(count: 3)
        phase = .postFlopDecision
        return .success(())
    }

    // MARK: - Post-flop decision

    private func betPostFlop() -> Result<Void, GameError> {
        let required = 2 * anteBet
        guard chipBalance >= required else {
            return .failure(.insufficientChips(required: required, available: chipBalance))
        }
        chipStore.chipBalance -= required
        playBet = required
        dealCommunity(count: 2)
        resolve()
        return .success(())
    }

    private func checkPostFlop() -> Result<Void, GameError> {
        dealCommunity(count: 2)
        phase = .postRiverDecision
        return .success(())
    }

    // MARK: - Post-river decision

    private func betPostRiver() -> Result<Void, GameError> {
        let required = anteBet
        guard chipBalance >= required else {
            return .failure(.insufficientChips(required: required, available: chipBalance))
        }
        chipStore.chipBalance -= required
        playBet = required
        resolve()
        return .success(())
    }

    private func fold() -> Result<Void, GameError> {
        playerFolded = true
        // Folding forfeits Ante and Blind, but Trips is independent of the
        // dealer and of the player's continued participation, so it still pays.
        let playerHand = HandEvaluator.evaluate(cards: playerHoleCards + communityCards)
        let dealerHand = HandEvaluator.evaluate(cards: dealerHoleCards + communityCards)
        let tripsOutcome = UTHRules.resolveTrips(player: playerHand)
        let tripsNet = BetResolution.netAmount(outcome: tripsOutcome, bet: Double(tripsBet))

        chipStore.chipBalance += tripsBet + Int(tripsNet.rounded())

        lastHandResult = HandResult(
            playerHand: playerHand,
            dealerHand: dealerHand,
            dealerQualifies: DealerQualification.qualifies(hand: dealerHand),
            anteOutcome: .lose,
            blindOutcome: .lose,
            playOutcome: .push,
            tripsOutcome: tripsOutcome,
            anteNet: -Double(anteBet),
            blindNet: -Double(blindBet),
            playNet: 0,
            tripsNet: tripsNet
        )
        chipStore.totalHandsPlayed += 1
        phase = .handComplete
        return .success(())
    }

    // MARK: - Resolution

    private func resolve() {
        phase = .resolving
        let playerHand = HandEvaluator.evaluate(cards: playerHoleCards + communityCards)
        let dealerHand = HandEvaluator.evaluate(cards: dealerHoleCards + communityCards)

        let result = BetResolution.resolve(
            playerHand: playerHand,
            dealerHand: dealerHand,
            anteBet: Double(anteBet),
            blindBet: Double(blindBet),
            playBet: Double(playBet),
            tripsBet: Double(tripsBet)
        )

        // Each wager returns (stake + net) to the chip stack: a win pays
        // 2× stake, a push pays 1× stake, a loss pays 0, and a Blind/Trips
        // bonus pays stake × (1 + multiplier).
        chipStore.chipBalance += anteBet  + Int(result.anteNet.rounded())
        chipStore.chipBalance += blindBet + Int(result.blindNet.rounded())
        chipStore.chipBalance += playBet  + Int(result.playNet.rounded())
        chipStore.chipBalance += tripsBet + Int(result.tripsNet.rounded())

        lastHandResult = result
        chipStore.totalHandsPlayed += 1
        phase = .handComplete
    }

    // MARK: - Reset

    private func collectAndReset() -> Result<Void, GameError> {
        deck.reset()
        playerHoleCards = []
        communityCards = []
        dealerHoleCards = []
        anteBet = 0
        blindBet = 0
        tripsBet = 0
        playBet = 0
        playerFolded = false
        lastHandResult = nil
        phase = .awaitingBets
        return .success(())
    }

    // MARK: - Helpers

    private func dealCommunity(count: Int) {
        for _ in 0..<count {
            communityCards.append(deck.deal()!)
        }
    }
}
