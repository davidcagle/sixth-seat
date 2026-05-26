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
    private(set) var playerFolded: Bool
    private(set) var errorMessage: String?

    /// Current ante wager selected in the pre-deal stake picker.
    /// Only meaningful while `phase == .awaitingBets`.
    var stagedAnte: Int

    /// Currently staged Trips side bet (0 = off). Committed to the engine
    /// via `placeTrips` when the player taps DEAL.
    private(set) var stagedTrips: Int

    /// Ante amount from the most recently resolved hand — `nil` until the
    /// first hand completes. Drives the REBET action at `.handComplete`.
    private(set) var lastAnteBet: Int?

    /// Trips amount from the most recently resolved hand; 0 if Trips was
    /// off on that hand. Only meaningful when `lastAnteBet != nil`.
    private(set) var lastTripsBet: Int = 0

    // MARK: - Animation state

    /// Top-level stage of the card-and-chip motion choreography. The view
    /// reads this to disable controls and to know which cards should be
    /// face-down vs. face-up in the current frame.
    private(set) var animationStage: AnimationStage = .idle

    /// Current resolution motion for each bet zone. Drives BetZoneView's
    /// pulse/slide/fade transforms.
    private(set) var anteAnimation:  BetZoneAnimation = .none
    private(set) var blindAnimation: BetZoneAnimation = .none
    private(set) var playAnimation:  BetZoneAnimation = .none
    private(set) var tripsAnimation: BetZoneAnimation = .none

    /// Cards (by identity) that have already completed their face-up flip.
    /// A card in this set should render face-up immediately on subsequent
    /// frames — flips happen once per hand.
    private(set) var revealedCards: Set<Card> = []

    /// Player hole cards are dealt face-down then flipped — for one beat
    /// after `deal()`, the engine has populated them but the view should
    /// still show the back of the card. Cleared on flip-completion.
    private(set) var playerCardsAwaitingFlip: Bool = false

    /// Monotonic per-hand counter, incremented on each successful `deal()`.
    /// Drives explicit `.id()` modifiers on the player hole-card and
    /// community-card views so SwiftUI tears down and recreates the
    /// CardView on every new hand — guarantees the new card starts in
    /// its initial face-down render state instead of inheriting the
    /// previous hand's view (where positional identity would otherwise
    /// let the old face-up rotation leak into the new hand).
    private(set) var currentDealId: Int = 0

    /// Balance the view should display *while animating* — distinct from
    /// `chipBalance` because the wager debits and payout credits happen on
    /// the engine before the chip motion completes. The view uses this so
    /// the displayed balance number arrives in sync with the chips.
    private(set) var displayedBalance: Int

    /// Active ceremony state, or `nil` when no ceremony is on screen.
    /// Drives the Tier 2-4 overlay views.
    private(set) var currentCeremony: CeremonyState?

    /// In-game bust flash, or `nil` when no flash is on screen. Drives the
    /// `BustFlashView` overlay shown after a hand resolves to a balance of
    /// zero. `.firstBust` carries the second-chance gift; `.secondBust`
    /// routes to the Chip Shop.
    private(set) var bustModal: BustModalKind?

    /// Tier 4 only. False during the 3500ms locked-in display window —
    /// taps are ignored. Flips true once the lock-in expires; from there
    /// either a tap or the 1500ms auto-advance timeout proceeds to chip
    /// resolution.
    private(set) var ceremonyAdvanceEnabled: Bool = false

    /// True while any choreography is in flight. Drives the global tap-to-
    /// skip gesture and disables all action buttons. Tracked by token
    /// rather than `animationStage` so the value flips synchronously the
    /// moment a player intent dispatches — Tasks may not have run yet.
    var isAnimating: Bool {
        animationToken != settledToken
    }

    // MARK: - Dependencies

    private let game: GameState
    private let chipStore: ChipStoreProtocol
    private let clock: AnimationClock
    private let haptics: HapticsService
    private let audio: AudioService
    private let telemetry: TelemetryService
    /// When true, every choreography call settles synchronously on the
    /// dispatching frame — used by engine-only unit tests that don't
    /// want to drive the animation Task.
    private let bypassAnimation: Bool

    /// Token incremented on every new animation run. Tap-to-skip bumps it,
    /// in-flight choreography checks it before each await — when the token
    /// no longer matches the run started under, the choreography exits and
    /// the snap-to-settled finalizer takes over.
    private var animationToken: Int = 0
    /// Last token whose choreography reached the finalized/settled state.
    /// `isAnimating == (animationToken != settledToken)`.
    private var settledToken: Int = 0
    private var pendingFinalBalance: Int?

    /// The table the player is seated at. Drives the Ante and Trips
    /// cycle ranges and the minimum stake. Set at init from the
    /// `TableSelectView` tap; never changes mid-session in V1.
    let tableConfig: TableConfig

    /// Amounts the Ante zone cycles through on tap. Zero is the cleared
    /// state (cycle wraps back to the first step). Blind auto-matches Ante,
    /// so each step actually requires 2× the listed amount in chips.
    /// Table-aware as of Session 15b (sourced from `tableConfig.anteCycle`).
    var anteCycle: [Int] { tableConfig.anteCycle }

    /// Amounts the Trips zone cycles through on tap. Zero represents "off".
    /// Table-aware as of Session 15b (sourced from `tableConfig.tripsCycle`).
    var tripsCycle: [Int] { tableConfig.tripsCycle }

    // MARK: - Init

    init(
        chipStore: ChipStoreProtocol? = nil,
        tableConfig: TableConfig = .defaultTable,
        clock: AnimationClock = RealAnimationClock(),
        haptics: HapticsService = GatedHapticsService(underlying: SystemHapticsService()),
        audio: AudioService = AVAudioService(),
        telemetry: TelemetryService = LoggingTelemetryService(),
        bypassAnimation: Bool = false
    ) {
        let store = chipStore ?? InMemoryChipStore()
        self.chipStore = store
        self.game = GameState(chipStore: store)
        self.tableConfig = tableConfig
        self.clock = clock
        self.haptics = haptics
        self.audio = audio
        self.telemetry = telemetry
        self.bypassAnimation = bypassAnimation

        self.phase = .awaitingBets
        self.chipBalance = store.chipBalance
        self.displayedBalance = store.chipBalance
        self.anteBet = 0
        self.blindBet = 0
        self.tripsBet = 0
        self.playBet = 0
        self.playerHoleCards = []
        self.dealerHoleCards = []
        self.communityCards = []
        self.lastHandResult = nil
        self.playerFolded = false
        self.errorMessage = nil
        self.stagedAnte = tableConfig.minimumAnte
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
        // Dealer cards stay face-down until the dealer-reveal flip lands.
        // Once a card is in `revealedCards`, the per-card check flips it.
        // This top-level flag stays true while any dealer card hasn't yet
        // been revealed — used to start cards in the back-of-card state.
        phase != .handComplete || dealerHoleCards.contains(where: { !revealedCards.contains($0) })
    }

    /// Whether a player hole card at `index` should render face-down on
    /// this frame. Player cards are dealt face-down then flipped during
    /// the `.dealingPlayer` choreography.
    func isPlayerCardFaceDown(index: Int) -> Bool {
        guard index < playerHoleCards.count else { return false }
        return !revealedCards.contains(playerHoleCards[index])
    }

    /// Whether a community card at `index` should render face-down. The
    /// engine populates communityCards before the flip plays out, so we
    /// gate visibility on per-card flip state during reveal stages.
    func isCommunityCardFaceDown(index: Int) -> Bool {
        guard index < communityCards.count else { return false }
        return !revealedCards.contains(communityCards[index])
    }

    /// Whether a dealer hole card at `index` should render face-down.
    func isDealerCardFaceDown(index: Int) -> Bool {
        guard index < dealerHoleCards.count else { return false }
        return !revealedCards.contains(dealerHoleCards[index])
    }

    var canDeal: Bool {
        phase == .awaitingBets && anteBet > 0
    }

    /// True when the player has the chips to commit to a worst-case
    /// main-bet round at the currently staged Ante: Ante + Blind +
    /// (4 × Ante) for the largest pre-flop Play bet = 6 × Ante. The
    /// DEAL button gates on this so the player can never start a hand
    /// they can't complete. (Session 12d)
    var canAffordDeal: Bool {
        phase == .awaitingBets
            && stagedAnte > 0
            && chipBalance >= stagedAnte * 6
    }

    /// True when the player can afford the worst-case main bet *and*
    /// the staged Trips on top: 6 × Ante + Trips. When false but
    /// `canAffordDeal` is true, the Trips zone force-clears to $0 so
    /// the player can still deal without Trips. (Session 12d)
    var canAffordTrips: Bool {
        phase == .awaitingBets
            && chipBalance >= stagedAnte * 6 + stagedTrips
    }

    /// True when the player has a prior hand to repeat and can afford its
    /// Ante (Blind auto-matches, so affordability is 2× the stored Ante).
    var canRebet: Bool {
        guard let ante = lastAnteBet else { return false }
        return chipBalance >= ante * 2
    }

    /// Trips amount to render in the Trips bet zone. While placing bets we
    /// show the staged value; once committed by `deal`, we show the engine
    /// value (which stays put until the hand resolves and resets).
    var displayedTripsBet: Int {
        phase == .awaitingBets ? stagedTrips : tripsBet
    }

    /// Whether the Trips zone should be interactive. Locked outside
    /// `.awaitingBets`, and locked when the staged Ante doesn't leave
    /// room for any Trips step on top of the worst-case main bet.
    /// (Session 12d affordability gate; Session 15b table-aware floor.)
    var isTripsZoneInteractive: Bool {
        guard phase == .awaitingBets else { return false }
        // The smallest non-zero Trips step is the table's first non-zero
        // tripsCycle entry; if even that doesn't fit on top of the
        // worst-case main bet, the zone is unaffordable for this Ante.
        return chipBalance >= stagedAnte * 6 + tableConfig.minimumTripsStep
    }

    /// Whether the Ante zone should be interactive. Only true while the
    /// player is placing bets — once DEAL fires, the zone locks.
    var isAnteZoneInteractive: Bool {
        phase == .awaitingBets
    }

    // MARK: - Intent handlers

    func placeAnte(amount: Int) {
        dispatch(.placeAnte(amount: amount))
    }

    /// Advances the Ante through $5 → $25 → $100 → $500 → $1,000 → $0
    /// → wrap. Unaffordable non-zero steps fall back to $0 (the cleared
    /// state) so we never stage a bet the player can't cover. Blind
    /// auto-matches Ante, so affordability is checked at 2× the step.
    /// No-op outside `.awaitingBets`. The view layer additionally gates
    /// onTap by `!isAnimating`, mirroring the Trips zone.
    ///
    /// After landing on a new Ante, any staged Trips that would push
    /// the total commitment above the worst-case affordable threshold
    /// (6 × Ante + Trips) is force-cleared. (Session 12d)
    func cycleAnteBet() {
        guard phase == .awaitingBets else { return }
        let before = stagedAnte
        let currentIndex = anteCycle.firstIndex(of: stagedAnte) ?? -1
        let nextIndex = (currentIndex + 1) % anteCycle.count
        let next = anteCycle[nextIndex]
        stagedAnte = (next == 0 || chipBalance >= next * 2) ? next : 0
        if stagedAnte != before {
            haptics.impact(.medium)
            if stagedAnte > 0 {
                audio.play(.chipPlace)
            }
        }
        // Drop staged Trips if the new Ante leaves no room for it on
        // top of the worst-case main bet. Trips does NOT auto-restore
        // when the player cycles back down — once cleared, the player
        // must re-tap Trips deliberately.
        if stagedTrips > 0 && chipBalance < stagedAnte * 6 + stagedTrips {
            stagedTrips = 0
        }
    }

    /// Advances the Trips side bet through off → $5 → $10 → $25 → off.
    /// Each candidate is gated against the worst-case main bet plus the
    /// step itself (6 × Ante + Trips) — unaffordable steps fall back to
    /// "off". No-op outside `.awaitingBets`. Also a silent no-op when
    /// the zone is unaffordable (`isTripsZoneInteractive` false): the
    /// view-layer `onTap` is already nil in that case, but a programmatic
    /// caller is held to the same gate. (Session 12d)
    func cycleTripsBet() {
        guard phase == .awaitingBets else { return }
        guard isTripsZoneInteractive else { return }
        let before = stagedTrips
        let currentIndex = tripsCycle.firstIndex(of: stagedTrips) ?? 0
        let nextIndex = (currentIndex + 1) % tripsCycle.count
        let next = tripsCycle[nextIndex]
        stagedTrips = (next == 0 || chipBalance >= stagedAnte * 6 + next) ? next : 0
        if stagedTrips != before {
            haptics.impact(.medium)
            if stagedTrips > 0 {
                audio.play(.chipPlace)
            }
        }
    }

    /// Commits the staged ante (and Trips, if any) and immediately deals.
    func deal() {
        guard !isAnimating else { return }
        if anteBet != stagedAnte {
            dispatch(.placeAnte(amount: stagedAnte))
            // If placing the ante failed we stop here.
            guard errorMessage == nil else { return }
        }
        if stagedTrips > 0 && tripsBet != stagedTrips {
            dispatch(.placeTrips(amount: stagedTrips))
            guard errorMessage == nil else { return }
        }
        #if DEBUG
        // Session 18c: if a DebugMenuView scenario was armed, swap the
        // engine's deck for the forced sequence before dispatching the
        // deal. Single-shot — `collectAndReset` reshuffles to a normal
        // 52-card random deck at hand end.
        if let scenario = DebugDealForcer.pendingScenario {
            DebugDealForcer.pendingScenario = nil
            game.setForcedDeck(Deck(forcedDealOrder: scenario.dealOrder))
        }
        #endif
        dispatch(.deal)
        guard errorMessage == nil else { return }
        currentDealId &+= 1
        playerCardsAwaitingFlip = true
        runAnimation { [weak self] token in
            await self?.animatePlayerHoleCards(token: token)
            await self?.maybeAnimateHandResolution(token: token)
        }
    }

    func betPreFlop(multiplier: Int) {
        guard !isAnimating else { return }
        dispatch(.betPreFlop(multiplier: multiplier))
        guard errorMessage == nil else { return }
        // Session 31: show the Play stake leaving the visible stack at the
        // moment of the wager, matching Ante/Blind/Trips. The Session 30
        // gate in syncFromGame suppressed displayedBalance entirely on the
        // .handComplete transition; this restores the post-debit intermediate
        // value so the dealer-reveal beat represents the resolution credit
        // (stake-back + net), not the full swing.
        displayedBalance -= playBet
        audio.play(.chipStackHandle)
        // Pre-flop bet reveals all five community cards, then dealer + chips.
        runAnimation { [weak self] token in
            await self?.animateAllCommunity(token: token)
            await self?.maybeAnimateHandResolution(token: token)
        }
    }

    func checkPreFlop() {
        guard !isAnimating else { return }
        dispatch(.checkPreFlop)
        guard errorMessage == nil else { return }
        // Pre-flop check reveals the flop and stops at .postFlopDecision.
        runAnimation { [weak self] token in
            await self?.animateFlop(token: token)
        }
    }

    func betPostFlop() {
        guard !isAnimating else { return }
        dispatch(.betPostFlop)
        guard errorMessage == nil else { return }
        // Session 31: see betPreFlop.
        displayedBalance -= playBet
        audio.play(.chipStackHandle)
        // Post-flop bet reveals turn + river together, then resolves.
        runAnimation { [weak self] token in
            await self?.animateTurnAndRiver(token: token)
            await self?.maybeAnimateHandResolution(token: token)
        }
    }

    func checkPostFlop() {
        guard !isAnimating else { return }
        dispatch(.checkPostFlop)
        guard errorMessage == nil else { return }
        // Post-flop check reveals turn + river, advances to .postRiverDecision.
        runAnimation { [weak self] token in
            await self?.animateTurnAndRiver(token: token)
        }
    }

    func betPostRiver() {
        guard !isAnimating else { return }
        dispatch(.betPostRiver)
        guard errorMessage == nil else { return }
        // Session 31: see betPreFlop. The highest-risk cell — placement and
        // resolution share this dispatch, so the tap-debit and reveal-credit
        // must not collapse into a single jump. The post-debit intermediate
        // value lives on displayedBalance from this line until the
        // chip-resolution finalizer in animateChipResolution lands the final.
        displayedBalance -= playBet
        audio.play(.chipStackHandle)
        // No new cards revealed — straight to dealer flip + chip resolution.
        runAnimation { [weak self] token in
            await self?.maybeAnimateHandResolution(token: token)
        }
    }

    func fold() {
        guard !isAnimating else { return }
        dispatch(.fold)
        guard errorMessage == nil else { return }
        audio.play(.fold)
        runAnimation { [weak self] token in
            await self?.maybeAnimateHandResolution(token: token)
        }
    }

    func newHand() {
        guard !isAnimating else { return }
        dispatch(.collectAndReset)
        // Session 30 (Build 2): pre-stage the table-minimum Ante on every
        // new hand to match first-entry behavior. A real UTH table posts
        // Ante + Blind every hand — there is no zero-bet state. The
        // tap-to-cycle UX still reaches $0 via the cycle if the player
        // wants to skip Trips/clear; this just gives DEAL an affordable
        // default instead of forcing a cycle tap into every hand.
        // Affordability gates (DEAL gate at 6× ante, bust detection) run
        // unchanged — a pre-stage that exceeds balance leaves DEAL
        // disabled, identical to first-entry. Trips stays cleared.
        stagedAnte = tableConfig.minimumAnte
        stagedTrips = 0
        resetAnimationState()
    }

    /// Restores the previous hand's Ante (and Trips, if affordable) and
    /// deals immediately. Intended as a one-tap replay from `.handComplete`.
    /// If the prior Trips bet is no longer affordable after the Ante is
    /// placed, Trips is skipped for this hand.
    func rebet() {
        guard !isAnimating else { return }
        guard let lastAnte = lastAnteBet else { return }
        guard chipBalance >= lastAnte * 2 else {
            errorMessage = "Not enough chips to rebet."
            return
        }
        if phase == .handComplete {
            dispatch(.collectAndReset)
            guard errorMessage == nil else { return }
            resetAnimationState()
        }
        stagedAnte = lastAnte
        let remainingAfterAnte = chipBalance - lastAnte * 2
        stagedTrips = (lastTripsBet > 0 && remainingAfterAnte >= lastTripsBet) ? lastTripsBet : 0

        if bypassAnimation {
            deal()
        } else {
            // Defer deal() so SwiftUI renders the cleared state
            // (revealedCards = {}, playerHoleCards = []) before the new
            // cards arrive. Without this gap the synchronous
            // {oldHandCards} → {} mutation of revealedCards above
            // fires the top-level .animation(value: revealedCards)
            // modifier against the just-dealt new cards — their
            // faceDown flips false → true under that implicit
            // animation, then collides with the deal-flip choreography
            // (left card no-flips, right card double-flips
            // face-up → face-down → face-up).
            Task { @MainActor [weak self] in
                self?.deal()
            }
        }
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
        let previousPhase = phase
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
        playerFolded = game.playerFolded

        // Snapshot the just-resolved wagers on the transition into
        // `.handComplete`. The engine still holds `anteBet`/`tripsBet`
        // at this point — they're only cleared by `collectAndReset`.
        if previousPhase != .handComplete && game.phase == .handComplete {
            lastAnteBet = game.anteBet
            lastTripsBet = game.tripsBet
            reportHandResolutionTelemetry()
        }

        // While animating, the displayed balance lags the engine — the
        // chip-resolution choreography updates it. Outside of animation,
        // it tracks the engine immediately.
        //
        // Session 30 (Build 2): suppress the immediate update when this
        // dispatch is the one that landed the engine on `.handComplete`.
        // The engine's perform() runs synchronously before `runAnimation`
        // flips `isAnimating` to true, so without this gate the post-
        // resolution balance leaks into the BALANCE label *before* the
        // dealer-reveal choreography plays — equivalent to the dealer
        // paying you before flipping their hole cards. The chip-resolution
        // finalizer at the end of `animateChipResolution` (or the
        // synchronous `finalizeSettledState` on bypass / skip-to-settled)
        // is the reconciliation point — every terminal dispatch is
        // immediately followed by `runAnimation`, so reconciliation is
        // guaranteed on all three settle paths. Bet-placement balance
        // changes during awaitingBets / preFlopDecision / postFlopDecision
        // / postRiverDecision keep their synchronous update, preserving
        // the SPEC 2026-05-11 "chips leave the stack when you bet"
        // behavior.
        //
        // Session 31 (Build 2): the three Play-bet wrappers
        // (betPreFlop / betPostFlop / betPostRiver) explicitly subtract
        // playBet from displayedBalance after dispatch, *after* this gate
        // has run. That layered write produces the post-debit intermediate
        // value the player sees during dealer reveal — the Play chips
        // visibly leave the stack at the tap, then the dealer-reveal beat
        // represents the resolution credit (stake-back + net) rather than
        // the full swing. This sharpens, not contradicts, the Session 30
        // contract: what freezes during the reveal is the resolution
        // *credit*, not the player's just-committed wager.
        let landedOnHandComplete = (previousPhase != .handComplete && game.phase == .handComplete)
        if !isAnimating && !landedOnHandComplete {
            displayedBalance = chipBalance
        }
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

    /// Fires `TelemetryService.handResolved` on the transition into
    /// `.handComplete`. Called from `syncFromGame` so the event lands
    /// the moment the engine reaches the hand's resolution — same beat
    /// as `lastAnteBet` / `lastTripsBet` snapshotting, before the
    /// dealer-reveal animation begins. Balance amounts are deliberately
    /// not included on the payload (privacy: derivable from purchase
    /// history + game outcomes server-side). (Session 19b)
    private func reportHandResolutionTelemetry() {
        guard let result = game.lastHandResult else { return }
        let tone: HandResultTone
        let net = result.totalNet
        if net > 0 { tone = .win }
        else if net < 0 { tone = .loss }
        else { tone = .push }

        let tripsOutcome: TripsTelemetryOutcome
        if game.tripsBet == 0 {
            tripsOutcome = .notPlaced
        } else {
            switch result.tripsOutcome {
            case .win, .blindBonus: tripsOutcome = .paid
            case .lose:             tripsOutcome = .lost
            case .push:             tripsOutcome = .notPlaced // Trips never pushes; defensive only.
            }
        }

        telemetry.handResolved(
            tableID: tableConfig.id,
            anteAmount: game.anteBet,
            tripsAmount: game.tripsBet,
            resultTone: tone,
            tripsOutcome: tripsOutcome
        )
    }

    // MARK: - Animation choreography

    /// Skips any in-flight animation and snaps to the fully-settled state:
    /// every dealt card face-up, all bet zone motions complete, displayed
    /// balance synced to the engine. Safe to call when nothing is running.
    ///
    /// During a Tier 4 jackpot ceremony's first 2500ms (the locked-in
    /// display window), taps are silently ignored to prevent accidental
    /// skips on the way in (decision 6).
    func skipToSettled() {
        guard isAnimating else { return }
        if animationStage == .jackpotCeremony && !ceremonyAdvanceEnabled {
            return
        }
        animationToken += 1  // invalidates any in-flight choreography
        finalizeSettledState()
        maybeShowBustFlash()
    }

    private func resetAnimationState() {
        animationStage = .idle
        anteAnimation = .none
        blindAnimation = .none
        playAnimation = .none
        tripsAnimation = .none
        revealedCards.removeAll()
        playerCardsAwaitingFlip = false
        pendingFinalBalance = nil
        currentCeremony = nil
        ceremonyAdvanceEnabled = false
        displayedBalance = chipBalance
        settledToken = animationToken
    }

    private func finalizeSettledState() {
        // Mark cards as revealed up to the visibility appropriate for the
        // current phase. Community cards are dealt face-down at hand start
        // (Session 12) and flip on phase transitions, so the bulk reveal
        // can't blanket-flip them — at .preFlopDecision the community
        // row is still face-down even though communityCards.count == 5.
        for card in playerHoleCards { revealedCards.insert(card) }
        switch phase {
        case .awaitingBets, .preFlopDecision:
            break
        case .postFlopDecision:
            for card in communityCards.prefix(3) { revealedCards.insert(card) }
        case .postRiverDecision, .resolving, .handComplete:
            for card in communityCards { revealedCards.insert(card) }
        }
        // On a fold, dealer cards stay face-down — Vegas tables don't expose
        // them and the player has surrendered the hand.
        if phase == .handComplete && !playerFolded {
            // If we're revealing dealer cards here (skip-to-settled mid-
            // dealer-reveal, or bypassAnimation in tests), fire the
            // `.cardFlip` SFX exactly once. The normal-path animation
            // already played it inside `animateDealerHoleCards`, so check
            // for un-revealed dealer cards before firing — same-SFX double-
            // play is what surfaced the Session 19a phone-test silence in
            // the first place (`AVAudioPlayer.currentTime = 0; play()` on
            // a mid-playback cached player). (Session 19b)
            let dealerCardsHidden = dealerHoleCards.contains { !revealedCards.contains($0) }
            if dealerCardsHidden {
                audio.play(.cardFlip)
            }
            for card in dealerHoleCards { revealedCards.insert(card) }
        }
        playerCardsAwaitingFlip = false
        anteAnimation = .none
        blindAnimation = .none
        playAnimation = .none
        tripsAnimation = .none
        currentCeremony = nil
        ceremonyAdvanceEnabled = false
        if let final = pendingFinalBalance {
            displayedBalance = final
            pendingFinalBalance = nil
        } else {
            displayedBalance = chipBalance
        }
        animationStage = phase == .handComplete ? .settled : .idle
        settledToken = animationToken
    }

    /// Spawns a Task that runs `body` against a fresh animation token. If
    /// the token is bumped mid-flight (skip-to-settled), `body` should
    /// short-circuit — every choreography helper checks via `isCurrent`.
    /// When the view model is in bypass mode, skips the body entirely and
    /// jumps to the settled state synchronously.
    private func runAnimation(_ body: @MainActor @escaping (_ token: Int) async -> Void) {
        if bypassAnimation {
            finalizeSettledState()
            maybeShowBustFlash()
            return
        }
        animationToken += 1
        let token = animationToken
        Task { @MainActor in
            await body(token)
            // If we still own this run (no skip happened), settle cleanly.
            if self.animationToken == token {
                self.finalizeSettledState()
                self.maybeShowBustFlash()
            }
        }
    }

    private func isCurrent(_ token: Int) -> Bool {
        animationToken == token
    }

    private func reveal(_ card: Card) {
        revealedCards.insert(card)
    }

    /// Reveals a card and fires the per-flip light haptic plus an
    /// optional SFX. Used by the staggered choreography paths (deal,
    /// flop, turn/river, dealer reveal). The bare `reveal(_:)` is kept
    /// for the bulk-reveal sweep in `finalizeSettledState`, which
    /// would otherwise burst 5-7 taps in ~16ms — unpleasant and not
    /// what the trigger map intends.
    ///
    /// `sfx` defaults to `nil` so callers must opt in explicitly. The
    /// trigger map (Session 19a): player hole-card flip → `.cardDeal`,
    /// community card → `.cardPlace`. Dealer reveal fires `.cardFlip`
    /// once at the top of `animateDealerHoleCards` rather than per card
    /// (Session 19b — see that method's docstring for the rationale),
    /// so the per-dealer-card reveals pass `sfx: nil` here.
    private func revealWithHaptic(_ card: Card, sfx: SoundEffect? = nil) {
        revealedCards.insert(card)
        haptics.impact(.light)
        if let sfx { audio.play(sfx) }
    }

    /// Player-deal flip: card 1 starts at 0ms (300ms), card 2 at 150ms (300ms).
    /// Total ~450ms.
    private func animatePlayerHoleCards(token: Int) async {
        guard isCurrent(token), playerHoleCards.count >= 2 else { return }
        animationStage = .dealingPlayer
        playerCardsAwaitingFlip = false

        // Explicit yield BEFORE the first reveal. In the fresh-DEAL flow
        // deal() runs from the Button's synchronous event handler, so
        // SwiftUI flushes the post-deal face-down render before this
        // Task body runs. In the REBET flow deal() is dispatched from a
        // deferred Task, and without a yield this Task body runs back-to-
        // back with that one — SwiftUI never gets to render the face-down
        // state for card 0 (whose reveal happens immediately), so card 0
        // appears face-up directly with no flip. Card 1 escapes that
        // because its reveal is delayed by the 150 ms sleep below, which
        // gives SwiftUI a render gap. The yield here equalizes the two.
        await Task.yield()
        guard isCurrent(token) else { return }

        revealWithHaptic(playerHoleCards[0], sfx: .cardDeal)
        await clock.sleep(milliseconds: 150)
        guard isCurrent(token) else { return }
        revealWithHaptic(playerHoleCards[1], sfx: .cardDeal)
        await clock.sleep(milliseconds: 300) // card 2's flip window
    }

    /// Flop: 200ms pause, then three cards staggered 200ms apart, 250ms each.
    private func animateFlop(token: Int) async {
        guard isCurrent(token), communityCards.count >= 3 else { return }
        animationStage = .revealingFlop

        // Yield before the first reveal so SwiftUI flushes the post-
        // dispatch face-down render even if a future scheduler change
        // runs this Task body back-to-back with checkPreFlop. Mirrors
        // the protection in animatePlayerHoleCards.
        await Task.yield()
        guard isCurrent(token) else { return }

        await clock.sleep(milliseconds: 200) // burn pause
        guard isCurrent(token) else { return }

        revealWithHaptic(communityCards[0], sfx: .cardPlace)
        await clock.sleep(milliseconds: 200)
        guard isCurrent(token) else { return }

        revealWithHaptic(communityCards[1], sfx: .cardPlace)
        await clock.sleep(milliseconds: 200)
        guard isCurrent(token) else { return }

        revealWithHaptic(communityCards[2], sfx: .cardPlace)
        await clock.sleep(milliseconds: 250) // final flip duration
    }

    /// Turn + River together: 200ms pause, two cards staggered 200ms apart.
    private func animateTurnAndRiver(token: Int) async {
        guard isCurrent(token), communityCards.count >= 5 else { return }
        animationStage = .revealingTurn

        // See animateFlop — yield to flush the post-dispatch face-down
        // render before the first reveal lands.
        await Task.yield()
        guard isCurrent(token) else { return }

        await clock.sleep(milliseconds: 200)
        guard isCurrent(token) else { return }

        revealWithHaptic(communityCards[3], sfx: .cardPlace)
        await clock.sleep(milliseconds: 200)
        guard isCurrent(token) else { return }

        animationStage = .revealingRiver
        revealWithHaptic(communityCards[4], sfx: .cardPlace)
        await clock.sleep(milliseconds: 250)
    }

    /// All five community cards at once: 200ms pause, then 5 staggered flips
    /// 150ms apart, 250ms each.
    private func animateAllCommunity(token: Int) async {
        guard isCurrent(token), communityCards.count >= 5 else { return }
        animationStage = .revealingFlopTurnRiver

        // See animateFlop — yield to flush the post-dispatch face-down
        // render before the first reveal lands.
        await Task.yield()
        guard isCurrent(token) else { return }

        await clock.sleep(milliseconds: 200)
        for i in 0..<5 {
            guard isCurrent(token) else { return }
            revealWithHaptic(communityCards[i], sfx: .cardPlace)
            if i < 4 {
                await clock.sleep(milliseconds: 150)
            } else {
                await clock.sleep(milliseconds: 250)
            }
        }
    }

    /// Dealer reveal: card 1 at 0ms (250ms), card 2 at 200ms (250ms).
    ///
    /// Audio: fires `.cardFlip` exactly once, synchronously, before the
    /// first `Task.yield()`. Session 19a originally fired it per card,
    /// but `AVAudioPlayer.currentTime = 0; play()` on the shared cached
    /// player re-triggers the same instance — the 200ms gap between the
    /// two dealer cards is shorter than the ~0.9s `card_flip.caf`, so the
    /// second `play()` restarted the first mid-playback and on iPhone 16
    /// Pro Max produced a silent showdown (Session 19a phone test). Firing
    /// once at the top also lands the SFX before any `await`, which means
    /// a tap-to-skip during dealer reveal still produces the audio cue.
    private func animateDealerHoleCards(token: Int) async {
        guard isCurrent(token), dealerHoleCards.count >= 2 else { return }
        animationStage = .revealingDealer

        // Single dealer-reveal audio beat — synchronous, before any await,
        // so a same-frame skip-to-settled still hears it. See docstring.
        audio.play(.cardFlip)

        // See animateFlop — yield to flush the post-dispatch face-down
        // render before the first reveal lands. Pairs with the
        // .id("dealer-card-\(currentDealId)-N") modifier in GameTableView
        // (Project Convention #4): without the yield, SwiftUI's positional
        // identity reuse can carry the prior hand's face-up dealer view
        // into the new hand and skip the face-down→face-up flip.
        await Task.yield()
        guard isCurrent(token) else { return }

        revealWithHaptic(dealerHoleCards[0])
        await clock.sleep(milliseconds: 200)
        guard isCurrent(token) else { return }
        revealWithHaptic(dealerHoleCards[1])
        await clock.sleep(milliseconds: 250) // final flip duration
    }

    /// Wraps the dealer reveal + (optional) ceremony + chip resolution
    /// chain. Only runs if the engine reached `.handComplete` on the
    /// dispatched action — checks + pre-flop bets and folds all qualify.
    /// On fold, both the dealer reveal and the ceremony are skipped:
    /// Vegas tables don't expose dealer cards on a fold, and a celebration
    /// of a hand the player surrendered would be wrong product-wise.
    /// Trips still resolves via `animateChipResolution` — `tripsOutcome`
    /// is computed independent of the dealer's cards.
    private func maybeAnimateHandResolution(token: Int) async {
        guard isCurrent(token), phase == .handComplete else { return }
        if !playerFolded {
            await animateDealerHoleCards(token: token)
            guard isCurrent(token) else { return }
            await clock.sleep(milliseconds: 100) // brief beat before next phase
            guard isCurrent(token) else { return }
            if let ceremony = makeCeremonyState() {
                await animateCeremony(ceremony, token: token)
                guard isCurrent(token) else { return }
            }
        }
        await animateChipResolution(token: token)
    }

    /// Builds the ceremony snapshot from the engine's last hand result, or
    /// returns nil when neither hand reaches Tier 2+.
    private func makeCeremonyState() -> CeremonyState? {
        guard let result = lastHandResult else { return nil }
        return CeremonyState.from(result: result)
    }

    /// Plays the ceremony beat for the given state. Tier 2 (.notable) and
    /// Tier 3 (.big) are timed displays — 1200ms / 2400ms respectively —
    /// that the universal tap-to-skip can interrupt at any time. Tier 4
    /// (.jackpot) is gated: the first 3500ms ignore taps (lock-in window),
    /// then a 1500ms tap-to-advance window runs to a 5000ms total cap.
    internal func animateCeremony(_ state: CeremonyState, token: Int) async {
        currentCeremony = state
        // Pre-stage the post-resolution balance so a tap-to-skip during
        // the ceremony lands on the engine's final balance — chip
        // resolution would otherwise have done this for us.
        pendingFinalBalance = chipBalance

        switch state.effectiveTier {
        case .standard:
            return // unreachable — makeCeremonyState filtered it out
        case .notable:
            animationStage = .ceremony
            if state.isPlayerWin {
                haptics.notification(.success)
            }
            await clock.sleep(milliseconds: 1200)
        case .big:
            animationStage = .ceremony
            if state.isPlayerWin {
                haptics.notification(.success)
                await clock.sleep(milliseconds: 90)
                guard isCurrent(token) else { return }
                haptics.impact(.medium)
            }
            await clock.sleep(milliseconds: 2400)
        case .jackpot:
            animationStage = .jackpotCeremony
            ceremonyAdvanceEnabled = false
            if state.isPlayerWin {
                haptics.notification(.success)
                await clock.sleep(milliseconds: 90)
                guard isCurrent(token) else { return }
                haptics.impact(.heavy)
                if state.playerHand == .royalFlush {
                    await clock.sleep(milliseconds: 90)
                    guard isCurrent(token) else { return }
                    haptics.impact(.heavy)
                }
            }
            await clock.sleep(milliseconds: 3500) // locked-in display
            guard isCurrent(token) else { return }
            ceremonyAdvanceEnabled = true
            await clock.sleep(milliseconds: 1500) // tap-to-advance window
        }

        guard isCurrent(token) else { return }
        currentCeremony = nil
        ceremonyAdvanceEnabled = false
    }

    private func animateChipResolution(token: Int) async {
        guard isCurrent(token), let result = lastHandResult else { return }
        animationStage = .resolvingChips

        let anteOutcome  = BetZoneOutcome.from(outcome: result.anteOutcome,  stake: anteBet)
        let blindOutcome = BetZoneOutcome.from(outcome: result.blindOutcome, stake: blindBet)
        let playOutcome  = BetZoneOutcome.from(outcome: result.playOutcome,  stake: playBet)
        let tripsOutcome = BetZoneOutcome.from(outcome: result.tripsOutcome, stake: tripsBet)

        // Fire the hand-level outcome SFX at the start of chip resolution.
        // Win SFX + chip payoff play simultaneously (Session 19a trigger map);
        // big vs small is gated on flush-or-better. Push is intentionally
        // silent. Fold skips this path entirely (no dealer reveal, no
        // ceremony) so the `.fold` SFX from `fold()` is the only audio cue.
        playHandResolutionSFX(result: result)

        // Snapshot the engine's current balance — that's where the displayed
        // value lands once chips arrive at the tray. Until then the view
        // continues to show the pre-resolution number.
        pendingFinalBalance = chipBalance

        // Open all four zones into their motion phase simultaneously so the
        // staggered durations themselves provide visual rhythm.
        applyZoneAnimation(zone: .ante,  outcome: anteOutcome,  phase: .pulsing)
        applyZoneAnimation(zone: .blind, outcome: blindOutcome, phase: .pulsing)
        applyZoneAnimation(zone: .play,  outcome: playOutcome,  phase: .pulsing)
        applyZoneAnimation(zone: .trips, outcome: tripsOutcome, phase: .pulsing)

        await clock.sleep(milliseconds: 150) // pulse / win-match window
        guard isCurrent(token) else { return }

        applyZoneAnimation(zone: .ante,  outcome: anteOutcome,  phase: .slide)
        applyZoneAnimation(zone: .blind, outcome: blindOutcome, phase: .slide)
        applyZoneAnimation(zone: .play,  outcome: playOutcome,  phase: .slide)
        applyZoneAnimation(zone: .trips, outcome: tripsOutcome, phase: .slide)

        // Slide window — long enough for the longest single-zone duration
        // (~700-800ms) while keeping things snappy.
        await clock.sleep(milliseconds: 550)
        guard isCurrent(token) else { return }

        // Balance "lands" — animate the number to the final value.
        if let final = pendingFinalBalance {
            displayedBalance = final
        }
        // Hold a beat for the number animation to land before settling.
        await clock.sleep(milliseconds: 150)
    }

    /// Fires the hand-level outcome SFX at the start of chip resolution.
    /// Big-win cutoff is flush-or-better — matches the prompt's mapping
    /// (and reads as casino-correct: flush is where the Blind bonus
    /// pays at a multiplier, so it's the natural threshold for the
    /// bigger sting). Push is silent (V1 design choice).
    private func playHandResolutionSFX(result: HandResult) {
        let net = result.totalNet
        if net > 0 {
            let bigWin = result.playerHand.rank >= .flush
            audio.play(bigWin ? .winBig : .winSmall)
            audio.play(.chipPayoff)
        } else if net < 0 {
            audio.play(.loss)
        }
        // net == 0 → push: intentionally silent.
    }

    private enum Zone { case ante, blind, play, trips }
    private enum AnimPhase { case pulsing, slide }

    private func applyZoneAnimation(zone: Zone, outcome: BetZoneOutcome, phase: AnimPhase) {
        // Fire the per-zone outcome haptic on the slide phase — that's the
        // moment chips visibly move, so it stays in sync with motion (and
        // losses, which skip the pulse, get the haptic at the right beat).
        if phase == .slide {
            switch outcome {
            case .loss: haptics.notification(.warning)
            case .push: haptics.impact(.soft)
            case .win, .noBet: break
            }
        }
        let value: BetZoneAnimation
        switch (outcome, phase) {
        case (.noBet, _):           value = .none
        case (.push, .pulsing):     value = .pulsing
        case (.push, .slide):       value = .slidingDown
        case (.win,  .pulsing):     value = .winMatched
        case (.win,  .slide):       value = .slidingDown
        case (.loss, .pulsing):     value = .none // losses don't pulse
        case (.loss, .slide):       value = .slidingUp
        }
        switch zone {
        case .ante:  anteAnimation  = value
        case .blind: blindAnimation = value
        case .play:  playAnimation  = value
        case .trips: tripsAnimation = value
        }
    }

    // MARK: - Bust flash

    /// Detects an in-game bust at the moment chip resolution lands the
    /// balance below `GameConstants.minimumPlayableBalance` — the
    /// cheapest table's `minimumEntryBalance`, i.e. no V1 table is
    /// enterable — and presents the appropriate flash modal:
    /// first-bust awards the second-chance bonus and resets the table to
    /// `.awaitingBets`; second-bust offers a route to the Chip Shop. The
    /// `hasReceivedSecondChanceBonus` flag is set at the moment the bonus
    /// is awarded — *before* the modal is shown — so a force-quit during
    /// the modal cannot replay the bonus on relaunch.
    private func maybeShowBustFlash() {
        guard phase == .handComplete else { return }
        guard chipStore.chipBalance < GameConstants.minimumPlayableBalance else { return }
        guard bustModal == nil else { return }

        if chipStore.hasReceivedSecondChanceBonus {
            presentSecondBust()
        } else {
            presentFirstBust()
        }
    }

    private func presentFirstBust() {
        // Award + flag set *before* presentation. BonusLogic enforces the
        // same guards (balance == 0 && !hasReceived) but at this point we
        // already know they hold, so this is effectively unconditional.
        BonusLogic.applySecondChanceBonusIfEligible(store: chipStore)

        // Sync the post-award balance into VM-visible state, then clear
        // the table so the player lands on the betting screen behind the
        // modal: collectAndReset drops `.handComplete` to `.awaitingBets`.
        haptics.notification(.success)
        bustModal = .firstBust
        dispatch(.collectAndReset)
        resetAnimationState()
        stagedAnte = tableConfig.minimumAnte
        stagedTrips = 0
        displayedBalance = chipBalance

        // Schedule the 5-second auto-dismiss through the animation clock so
        // tests can drive the timing deterministically. Skipped under
        // `bypassAnimation` so synchronous unit tests don't leak Tasks.
        guard !bypassAnimation else { return }
        Task { @MainActor [weak self] in
            await self?.clock.sleep(milliseconds: 5_000)
            guard let self else { return }
            // Only auto-dismiss if the first-bust modal is still on screen
            // (player may have tapped to dismiss in the meantime, or the
            // modal may have been replaced by a second-bust on a follow-up
            // hand — the auto-dismiss must not interfere with that).
            if self.bustModal == .firstBust {
                self.bustModal = nil
            }
        }
    }

    private func presentSecondBust() {
        haptics.notification(.warning)
        bustModal = .secondBust
        dispatch(.collectAndReset)
        resetAnimationState()
        stagedAnte = 0
        stagedTrips = 0
    }

    /// Hides the bust flash modal. Called by the modal's tap-to-dismiss
    /// gesture and by the "Visit Chip Shop" button right before the
    /// view layer pushes the chip-shop route onto the navigation stack.
    func dismissBustModal() {
        bustModal = nil
    }

    // MARK: - Outcome inspection (for tests + view)

    /// Public outcome for each bet zone in the most recently resolved hand.
    /// Returns `.noBet` if the hand isn't resolved or the zone had no stake.
    func zoneOutcome(_ zone: BetZoneIdentifier) -> BetZoneOutcome {
        guard let result = lastHandResult else { return .noBet }
        switch zone {
        case .ante:  return BetZoneOutcome.from(outcome: result.anteOutcome,  stake: anteBet)
        case .blind: return BetZoneOutcome.from(outcome: result.blindOutcome, stake: blindBet)
        case .play:  return BetZoneOutcome.from(outcome: result.playOutcome,  stake: playBet)
        case .trips: return BetZoneOutcome.from(outcome: result.tripsOutcome, stake: tripsBet)
        }
    }

    // MARK: - Formatting

    // MARK: - Test hooks

    /// Runs only the ceremony beat for the given synthetic state under a
    /// fresh animation token — no dealer reveal, no chip resolution. Used
    /// by tests to drive Tier 4 timing/gating without rolling a real
    /// jackpot hand from the deck.
    func _testRunCeremony(_ state: CeremonyState) {
        if bypassAnimation {
            currentCeremony = state
            currentCeremony = nil
            return
        }
        animationToken += 1
        let token = animationToken
        Task { @MainActor in
            await self.animateCeremony(state, token: token)
            if self.animationToken == token {
                self.finalizeSettledState()
            }
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()
}
