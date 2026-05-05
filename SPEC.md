# 6th Seat Hold'em — Project Spec

Durable reference: locked design decisions, paytables, animation specs, architecture conventions. This file changes rarely, only when real design decisions change. For session-by-session progress, see `HANDOFF.md`.

> Canonical project docs live at the repo root as `SPEC.md` (this file) and `HANDOFF.md` as of Session 14c-prep-2. The Google Drive copy at `Planning/CLAUDE.md.gdoc` is now legacy and may be deleted.

## Project Overview

A free-to-play casino table game app for iOS and macOS. Players play heads-up Ultimate Texas Hold'em against the house (dealer). One player versus the dealer; no other seats at the table. "6th Seat" is a narrative frame — the player is stepping into the sixth seat of an implied casino table. No real-money gambling. No ads. Monetized through in-app chip purchases.

Full product spec: See docs/PDR.docx in Google Drive for the complete Product Design Review.

## Tech Stack

* Language: Swift 5.9+
* UI Framework: SwiftUI
* Target: iOS 17+ / macOS 14+ (Universal App)
* Payments: StoreKit 2 (Apple In-App Purchase)
* Local Storage: SwiftData or UserDefaults (chip balance, settings, preferences)
* No backend required for V1 — all game logic runs client-side

## Game Rules (Ultimate Texas Hold'em)

UTH is a casino table game where each player competes independently against the dealer. It is NOT player-vs-player poker.

### Hand Flow

1. Player places mandatory Ante and Blind bets (equal amounts)
2. Player optionally places Trips side bet
3. Dealer deals 2 hole cards to each player and 2 to the dealer (face down)
4. Pre-flop decision: Player may bet 3x or 4x Ante (Play bet), or check
5. Dealer reveals 3-card flop (community cards)
6. Post-flop decision: If player hasn't bet, may bet 2x Ante, or check
7. Dealer reveals turn and river (2 more community cards)
8. Post-river decision: If player still hasn't bet, must bet 1x Ante or fold
9. Dealer reveals hole cards. Dealer must have pair or better to qualify
10. Hands are compared. Bets are resolved.

### Dealer Qualification

* Dealer qualifies with a pair or better
* If dealer does NOT qualify: Ante pushes (returned), Play bet pays 1:1
* If dealer qualifies: Both Ante and Play resolved against dealer hand

### Side Bets

* Trips: Optional side bet. Pays on player's best 5-card hand if three-of-a-kind or better. Independent of dealer hand and dealer qualification.
* Blind: Mandatory bet equal to Ante. Pays bonus on straight or better per Blind paytable. Pushes on wins below straight. Loses with the Ante on a losing hand.
* Pairs Plus is not offered in V1. (Removed during scope reconciliation — non-standard for UTH and adds variance without strategic depth.)
## Payout Tables

Blind Bonus Payouts:

* Royal Flush: 500:1
* Straight Flush: 50:1
* Four of a Kind: 10:1
* Full House: 3:1
* Flush: 3:2
* Straight: 1:1
* All other wins: Push

Trips Payouts:

* Royal Flush: 50:1
* Straight Flush: 40:1
* Four of a Kind: 30:1
* Full House: 8:1
* Flush: 6:1
* Straight: 5:1
* Three of a Kind: 3:1



## Table Configuration

* **Heads-up format:** 1 human player vs. dealer. No AI players, no other seats.
* Portrait orientation only on iPhone; equivalent layout adapted for iPad and macOS.
* **Three stake levels in V1:** $10, $25, $50 (Ante minimums). Player chooses stake before each session via Table Select screen.
* **Chip denominations:** $5 / $25 / $100 / $500 / $1,000 (five chips total). The $5 chip is the smallest denomination but is rarely used as the default unit at the $25 and $50 tables — primarily relevant at the $10 table and for change-making.

_Rationale: Heads-up was chosen because (a) phone screen real estate is better used for a single seat, (b) UTH is mathematically a heads-up game — other players don't affect outcomes — so multi-seat is decorative only, and (c) it removes the AI player behavior workstream entirely._
## Chip Economy

### Free Chips

* New player starting bankroll: 5,000 chips
* One-time second-chance bonus: 2,500 chips (triggered the first time chip resolution lands balance at 0 in-game; see Architectural Decisions for trigger semantics)

### In-App Purchases (StoreKit 2)

Five consumable chip bundles. Reference USD prices below; the actual displayed price is sourced from `Product.displayPrice` at runtime via StoreKit. Chip quantities are V1-final (not TBD — balance during TestFlight may inform a V2 retune, but V1 ships these values).

| Product ID | Display Name | Price (ref.) | Chips | Badge |
|---|---|---|---|---|
| `com.sixthseat.uth.chips.pocketchange` | Pocket Change | $0.99 | 5,000 | — |
| `com.sixthseat.uth.chips.starter` | Starter Stack | $1.99 | 25,000 | — |
| `com.sixthseat.uth.chips.tablestakes` | Table Stakes | $4.99 | 75,000 | Most Popular |
| `com.sixthseat.uth.chips.highroller` | High Roller | $9.99 | 250,000 | — |
| `com.sixthseat.uth.chips.deepstack` | Deep Stack | $19.99 | 750,000 | Best Value |

**First-purchase doubler.** Until the player completes their first paid purchase on this install, every tier displays and credits 2× its base chip amount. The doubler flag (`hasMadeFirstPurchase`) is per-device-install — if the player reinstalls the app the flag resets and the doubler re-arms. Cross-device first-purchase tracking via iCloud or a backend is a V2 candidate. Restore Purchases never re-fires the doubler — the flag was already consumed when the underlying purchase originally happened.

Apple takes 30% commission on all IAP.

## Visual & Audio Design

### Visual Style

* Realistic Vegas casino aesthetic — NOT cartoon, flat, or arcade
* Green felt table, glossy chips, professional card rendering
* Dark warm palette: deep green felt, dark wood/leather rail, gold/brass accents
* Premium and restrained — think Bellagio, not circus
* Portrait orientation only. All UI is designed for portrait phone screens; landscape is not supported in V1.

### Audio

* Card deal, flip, fold, shuffle sounds
* Chip place, stack, slide sounds
* Win (small), win (big/side bet), loss sounds
* UI tap and transition sounds
* Ambient casino loop (toggleable in settings)
* No dealer voice in V1

### Asset Locations

All visual assets from Fiverr designer are in Assets/Graphics/ All audio assets are in Assets/Audio/ File naming conventions:

* Graphics: descriptive (card_hearts_ace.png, chip_red_5.png, btn_bet_normal.png)
* Audio: sfx_ prefix for SFX, amb_ for ambient (sfx_card_deal.wav, amb_casino_loop.wav)

## Key Screens

1. Main Menu — Play, Settings, Chip Shop
2. Table Select — Choose table stake ($10, $25, $50). Three selection cards.
3. Game Table — Primary gameplay screen (heads-up table view, betting zones, chip tray, action bar)
4. Chip Shop — IAP store (five tiers from $0.99 to $19.99) with first-purchase doubler banner and Restore Purchases affordance
5. Settings (modal over Game Table) — Audio toggles (Music, Sound Effects, Vibrations) + Main Menu return
6. Payout (modal over Game Table) — Reference paytable for Blind Bonus and Trips
7. Win modal (over Game Table) — Win amount + Deal Again CTA + Main Menu secondary
8. Bust / Second-Chance flash modal — Triggered when balance hits 0 in-game (per Session 12b architectural decision)
## Architecture Guidelines

### Game Engine

* All game logic client-side in V1
* Use SystemRandomNumberGenerator for fair card distribution
* Implement proper 5-card poker hand evaluator (must handle all UTH outcomes)
* Dealer AI follows strict UTH house rules (no strategy, just qualification check)


### Key Technical Requirements

* SwiftUI animations for card dealing, chip movement, state transitions
* StoreKit 2 for IAP (handle purchases, restore transactions, receipt validation)
* Universal app for iOS and macOS (single codebase)
* Minimum tap target: 44x44pt (Apple HIG)
* Support Dynamic Type for accessibility
* Dark mode support

### Code Organization (suggested)

```
6thSeat/
├── App/                  # App entry point, app delegate
├── Models/
│   ├── Card.swift        # Card, Deck, Suit, Rank
│   ├── Hand.swift        # Hand evaluation, comparison
│   ├── Player.swift      # Player model (human + AI)
│   ├── Dealer.swift      # Dealer logic, qualification
│   ├── GameState.swift   # Game state machine
│   └── ChipBank.swift    # Chip balance, transactions
├── Views/
│   ├── MainMenuView.swift
│   ├── TableSelectView.swift
│   ├── GameTableView.swift
│   ├── ChipShopView.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── GameViewModel.swift    # Core game logic
│   └── ShopViewModel.swift    # IAP logic
├── Services/
│   ├── HandEvaluator.swift    # Poker hand evaluation
│   ├── PayoutCalculator.swift # Bet resolution + side bets
│   ├── AudioManager.swift     # Sound playback
│   └── StoreManager.swift     # StoreKit 2 integration
├── Components/                # Reusable UI components
│   ├── CardView.swift
│   ├── ChipView.swift
│   ├── BettingZoneView.swift
│   └── PlayerSeatView.swift
├── Assets.xcassets/           # Image assets
└── Audio/                     # Sound files
```

## V1 Scope (Launch)

IN:

* Heads-up UTH (player vs. dealer only)
* Full UTH rules (Ante, Blind, Play) including 3x/4x pre-flop, 2x post-flop, 1x post-river or fold
* Trips side bet
* Blind bonus paytable (Vegas paytable)
* Three stake levels: $10, $25, $50 (player selects via Table Select screen)
* Chip shop with 5 IAP tiers and per-install first-purchase doubler
* Starting bankroll (5,000 chips) + one-time second-chance bonus (2,500 chips)
* Bust detection with second-chance flash modal
* Vegas visual style with sound effects (music, SFX, vibrations all toggleable)
* iOS + macOS universal app
* Portrait orientation only on iPhone
* Settings modal, Payout modal, Win modal

OUT (V2 candidates):

* Pairs Plus side bet (cut for V1 to keep scope tight; non-standard at most casinos)
* Multi-seat / 6-player table (heads-up is the V1 design; multi-seat is decorative for UTH and was descoped)
* AI table players (companion seats; not needed for heads-up)
* Avatar system (player + dealer + 5 AI avatars; cut with multi-seat)
* Landscape orientation
* Additional table stakes beyond $10/$25/$50 (e.g., $5 micro stakes, $100+ high stakes)
* Real-time multiplayer / drop-in tables
* Player accounts / authentication
* Backend server infrastructure
* iCloud-synced first-purchase doubler (per-device-install only in V1)
* Leaderboards
* Social features (chat, friends)
* Additional game modes (tournaments, high-stakes)

## Resolved Scope Drift Log

Decisions made in chat that previously drifted between SPEC.md, Fiverr brief, and `userMemories`. Listed here as a permanent record so future reconciliation can verify against this list.

| Date | Decision | Status |
|---|---|---|
| Pre-Session 1 | Heads-up format (not 6-seat) | ✅ in build, locked in Fiverr v1.1 |
| Pre-Session 1 | Pairs Plus excluded | ✅ in build, locked in Fiverr v1.1 |
| Pre-Session 1 | Portrait orientation only | ✅ in build, locked in Fiverr v1.1 |
| Pre-Session 1 | Avatars excluded | ✅ in build, locked in Fiverr v1.1 |
| Pre-Session 1 | Chip set: $5/$25/$100/$500/$1,000 | ✅ in build, locked in Fiverr v1.1 |
| Session 14a | Starter bonus applied eagerly in `UserDefaultsChipStore.init` (5,000 chips) | ✅ in build |
| Session 12b | Second-chance bonus = 2,500 chips on first bust | ✅ in build |
| Session 16 | First-purchase doubler (per-install) | ✅ in build |
| 2026-04-30 | SPEC Chip Economy section corrected (was: starter 2,500 + bonus 1,500; now: starter 5,000 + bonus 2,500) | doc fix |
| 2026-04-30 | Three stake levels: $10/$25/$50 (no $5/$15) | ✅ in build, supersedes Fiverr v1.1 |
| 2026-04-30 | Win modal: "Deal Again" primary CTA | UI work pending |
| 2026-04-30 | Settings: remove Restart button | UI work pending |
| 2026-04-30 | "DEALER" label becomes dynamic hand-strength readout | UI work pending |
| 2026-04-30 | Pre-flop raise: 3x and 4x both available | UI work pending |
| 2026-05-04 | Currency display: standard `$` format (e.g., `$3,935`) — supersedes earlier "no $ symbol" decision after build review confirmed `$` reads as authentic casino and Apple 4.3 compliance is satisfied via 17+ rating + Simulated Gambling descriptor + App Store description disclosure | ✅ in build |
| 2026-05-04 | Main Menu layout: four-button vertical nav (Play / Chip Shop / Settings / How to Play) with balance display at top — no gear icon | ✅ in build |
| 2026-05-04 | Table Select layout: vertical stacked list of three cards (not carousel), showing minimum bet + bet range per card, with "LAST PLAYED" badge | ✅ in build |

**Maintenance rule:** when a product or feature decision is made (scope cut, format change, UI behavior lock, currency convention, etc.), add an entry here in the same session it's decided. Same discipline as the Architectural Decisions log above.
## App Store Requirements

* Apple Developer Program enrollment required ($99/year)
* Age rating: 17+ (simulated gambling)
* Must comply with Apple Guidelines section 4.3 (simulated gambling)
* Privacy policy required
* No real-money gambling language or imagery

## Development Priorities (build order)

1. Card and Deck models + hand evaluator (core engine)
2. Game state machine (betting rounds, dealer logic, hand resolution)
3. Payout calculator (all bet types including side bets)
4. Basic game table UI (functional, not polished)
5. AI player behavior
6. Visual polish (integrate designer assets, animations)
7. Audio integration
8. Chip economy + StoreKit 2 IAP
9. Menu screens, settings, chip shop UI
10. TestFlight beta testing + chip economy balancing
11. App Store submission

## Project Conventions

1. **Engine/app separation.** The portable game engine (deck, hand evaluator, UTH rules, game state, payout calculator) lives in its own package and never imports SwiftUI. The app layer consumes the engine through published view models.
2. **ChipStore-shaped persistence.** All persistence is fronted by a `ChipStore` protocol. View models talk to the protocol; concrete implementations (`UserDefaultsChipStore` in production, `InMemoryChipStore` in tests) sit behind it.
3. **Inject-protocol-with-test-doubles.** Whenever a component crosses an external boundary (persistence, audio, haptics, randomness), define a protocol and inject the production type into shipping code and an in-memory test double into tests.
4. **Per-deal SwiftUI view identity.** Any card view rendered as part of a deal sequence must carry `.id("<role>-card-\(currentDealId)-\(index)")` on the SwiftUI view, AND its animation entry point must `await Task.yield()` before mutating animation state. Without both, SwiftUI's positional-identity reuse will keep the prior hand's view in place and bypass the face-down→face-up flip. Established for player cards in Session 10b, extended to community cards in Session 14a.

## Architectural Decisions

* Starter bonus is applied eagerly in `UserDefaultsChipStore.init`. Menu mounts with non-zero balance on fresh install. (Session 14a)
* Second-chance bonus trigger gate: `balance == 0 && hasReceivedStarterBonus && !hasReceivedSecondChanceBonus`. Triggers at the menu boundary on Play tap, not at game entry. (Session 14, refined in Session 14a)
* `hasReceivedStarterBonus` is a persisted flag in `PersistenceKeys`. (Session 14a)
* Production `ChipStore` = `UserDefaultsChipStore` (self-applies starter bonus). Test `ChipStore` = `InMemoryChipStore` (does not, by design). The invariant "balance is non-zero on first menu render" depends on `UserDefaultsChipStore` being the production path.
* Bust detection fires in-game at the moment chip resolution lands balance at 0, not at the menu boundary. First bust awards 2,500 second-chance chips with a brand-voiced flash modal. Second bust routes to Chip Shop via flash modal with navigation button. The `hasReceivedSecondChanceBonus` flag is set at moment of award (before modal display) to protect against force-quit replay. The Session 14 menu-boundary check remains as a fallback. (Session 12b)
* Bust threshold and affordability gates. The bust threshold is `chipBalance < GameConstants.minimumPlayableBalance`, where `minimumPlayableBalance = 2 × minimum chip value` (currently $10 with $5 minimum chips). This represents "cannot place Ante + Blind at the smallest cycle position." The DEAL button is gated on `chipBalance >= 6 × stagedAnte` (worst-case main bet: Ante + Blind + 4× Play). Trips is optional and is force-cleared and disabled when `chipBalance < (6 × stagedAnte) + tripsAmount`. Trips re-enables when affordable but does not auto-restore previous values. (Session 12d)
* **IAP idempotency invariant.** A given `Transaction.id` MUST NOT credit chips twice. The engine's `ChipPurchaseProcessor` enforces this with a persisted set (`PersistenceKeys.processedTransactionIDs`) consulted at the top of every credit attempt — a transaction whose id is already present is a no-op. This is the load-bearing defense against listener replay (`Transaction.updates` re-emitting after a force-quit), restore re-emission, and Family Sharing redelivery. Both the production `StoreKitIAPService` and the in-memory test double route through the same processor so the test double cannot drift. The first-purchase doubler flag (`hasMadeFirstPurchase`) is flipped to `true` *before* chips are credited — same force-quit-safety pattern as `hasReceivedSecondChanceBonus` from Session 12b. (Session 16)
* **Asset pipeline boundary.** Every visual asset (card faces, card back, chip denominations, chip stacks) is fronted by an `AssetService` protocol with two implementations: `BundleAssetService` (production, resolves named imagesets in `App/Assets.xcassets`) and `InMemoryAssetService` (tests, records every request and returns SF Symbol placeholders). Pure name-mapping logic lives in `AssetNames` so both paths resolve through the same code. Views consume the service via the SwiftUI environment (`\.assets`); production gets `BundleAssetService` by default and tests inject the in-memory double via `.environment(\.assets, ...)`. The asset catalog ships with placeholder imagesets for all 83 Phase-1 slots (52 card faces + 1 card back + 5 chip denominations + 25 chip-stack variants) so dropping the designer's PNG into the matching imageset is the only integration step. (Session 17)
* **Chip-stack height variants live in the engine.** `StackHeight` (`.h1 / .h3 / .h5 / .h10 / .h20`) is a public enum on the engine package with a `bestFit(for:)` rounder. Lives engine-side because it's pure integer arithmetic and the rounder is asserted by engine tests; the app reads it through `AssetService.chipStackImage(denomination:height:)`. (Session 17)

## Workflow Lessons

**Latent-invariant audits during refactors.** When changing what data exists at what time, or what state transitions can occur in what order, the change can surface bugs that were structurally invisible before. Two failure modes:

(a) Production code paths quietly assumed the old shape. A code path that was a no-op under old conditions becomes active under new conditions and produces wrong behavior. Example: Session 12's `finalizeSettledState` bulk-flipped community cards face-up — harmless when `communityCards` was empty pre-refactor, broken once all 5 cards existed from deal time.

(b) Existing tests' setup conditions inadvertently establish the new behavior's preconditions, producing false failures or false passes. Example: Session 12b's `rebetInsufficientChipsShowsError` set `hasReceivedSecondChanceBonus: false` and `balance: 0`, which under the new in-game bust detection auto-fires the first-bust modal and contaminates the rebet assertion.

Mitigation: when a refactor changes data shape, state machine, or trigger ordering, explicitly audit (1) every site that iterates over affected collections, (2) every test whose setup conditions touch the changed state. Tests catch (a) when they fail visibly. Catching (b) requires reading test setups, not just running them.

Pattern observed in Sessions 12, 12a, and 12b. Recurred in Session 16 (transaction listener now runs from app launch; new `hasMadeFirstPurchase` and `processedTransactionIDs` keys persist across launches; existing `ChipStoreTests`, `MainMenuViewTests`, and `BustFlowTests` had to be audited because their setup conditions touched `ChipShopView` instantiation and the in-memory store's defaults). Expected to recur again in Session 18 (real asset integration changing render timing).
