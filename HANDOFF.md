# 6th Seat: Ultimate Texas Hold'em

> Canonical handoff doc lives at repo-root `HANDOFF.md` as of Session 14c-prep. The Google Drive copy at `Planning/CLAUDE.md.gdoc` is now legacy and may be deleted.

**Last updated:** 2026-04-27, post-Session 14a (003caeb on `main`)

**Project completion estimate:** ~78% complete (was ~75%)

## Project History

| Session | Summary | Net lines |
|---|---|---|
| 14 | Main Menu screen + NavigationStack routing + persistent ChipStore | 224 |
| 14a | Bug fixes: bonus stacking on first launch, community cards face-down regression | 232 |

(Earlier sessions 1–11 are reconstructable from `git log --oneline` on `main`.)

## Project Overview

A free-to-play casino table game app for iOS and macOS. Players sit at a virtual 6-seat Ultimate Texas Hold'em table and play against the house (dealer). No real-money gambling. No ads. Monetized through in-app chip purchases.

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
2. Player optionally places Trips and/or Pairs Plus side bets
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

* Trips: Pays on player's best 5-card hand. Three-of-a-kind or better wins. Independent of dealer hand.
* Blind: Mandatory bet equal to Ante. Pays bonus on straight or better. Pushes on wins below straight.
* Pairs Plus: Pays if player's 2 hole cards form a pair or better. Independent of dealer hand and main bet outcome.

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

Pairs Plus Payouts:

* Pocket Aces: 30:1
* Suited Aces/Kings: 20:1
* Suited Pair: 10:1
* Pair: 5:1

Note: Pairs Plus payout table may vary. Verify against desired house edge before finalizing.

## Table Configuration

* 6 seats: 1 human player + 5 AI players
* AI players use basic strategy (bet/fold decisions based on hand strength)
* All players play against the same dealer hand independently
* Table stakes adjustable: $5 / $10 / $15 / $25 minimum bet

## Chip Economy

### Free Chips

* New player starting bankroll: 2,500 chips
* One-time second chance bonus: 1,500 chips (triggered after first bankroll depleted)

### In-App Purchases (StoreKit 2)

* Starter Stack: $1.99
* Table Stakes: $4.99
* High Roller: $9.99
* Exact chip quantities per tier TBD (balance during TestFlight beta)
* Apple takes 30% commission on all IAP

## Visual & Audio Design

### Visual Style

* Realistic Vegas casino aesthetic — NOT cartoon, flat, or arcade
* Green felt table, glossy chips, professional card rendering
* Dark warm palette: deep green felt, dark wood/leather rail, gold/brass accents
* Premium and restrained — think Bellagio, not circus

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
2. Table Select — Choose table stakes ($5, $10, $15, $25)
3. Game Table — Primary gameplay (overhead table view, betting zones, chip tray)
4. Chip Shop — IAP store ($1.99 / $4.99 / $9.99 packs)
5. Settings — Audio toggles (SFX on/off, ambient on/off), table preferences

## Architecture Guidelines

### Game Engine

* All game logic client-side in V1
* Use SystemRandomNumberGenerator for fair card distribution
* Implement proper 5-card poker hand evaluator (must handle all UTH outcomes)
* Dealer AI follows strict UTH house rules (no strategy, just qualification check)
* AI player behavior: basic strategy based on hand strength, varied betting patterns for realism

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

### Current File Inventory (post-Session 14a)

App/Views additions and annotations:

* `MainMenuView.swift` (encloses `MenuDestination` enum + `MainMenuLogic` helpers)
* `SettingsView.swift` (stub — Session 15)
* `ChipShopView.swift` (stub — Session 16)
* `HowToPlayView.swift` (stub — Session 15)

Engine package additions:

* `UserDefaultsChipStore` (real production implementation, applies starter bonus eagerly on init)

App description note:

> `ContentView` is now a `NavigationStack` shell with a `GameDestinationView` wrapper that owns `GameTableViewModel` via `@State`.

## V1 Scope (Launch)

IN:

* Single-player UTH against AI dealer
* 5 AI table players for ambiance
* Full UTH rules (Ante, Blind, Play)
* All three side bets (Trips, Blind bonus, Pairs Plus)
* Adjustable table stakes ($5-$25)
* Chip shop with 3 IAP tiers
* Starting bankroll + one-time bonus
* Vegas visual style with sound effects
* iOS + macOS universal app
* Settings screen

OUT (V2):

* Real-time multiplayer / drop-in tables
* Player accounts / authentication
* Backend server infrastructure
* Leaderboards
* Social features (chat, friends, avatars customization)
* Additional game modes (tournaments, high-stakes)

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

## Workflow Lessons

* Start every session with: `git checkout main && git pull && git log --oneline -5`. Confirm latest commit matches expectation before doing anything else. For bug-fix sessions, also verify the reported bug reproduces locally before fixing — don't fix what isn't broken on the current build.

## Open Items / Housekeeping

**Phone test pending across Sessions 11/14/14a.** Items to feel for:

1. Tier 3 timing at 2400ms — does it breathe or did we overshoot?
2. Royal-flush triple-tap distinctness on hardware (V1.5 fallback to `CHHapticEngine` if it reads as fuzzy buzz)
3. Fold-loop pacing — Vegas-pace or jarring?
4. Tier 1 flatness — confirm Session 11's polish fixed it (probably yes, but verify)
5. Main Menu visuals + button readability + navigation flow
6. Second-chance bonus flow on hardware: drive balance to 0, confirm bonus fires correctly on Play tap (not on entry, not stacked)
7. Verify community-card face-down deal works correctly across multiple consecutive hands (the Session 14a regression repro path)

**Other tracked items:**

* Dealer-card view identity pattern missing — Session 14c will fix. See Session 14b finding.

## What's Next

* ~~Session 12~~ — struck entirely (decision was made and confirmed).
* **Session 14 — done.**
* **Session 14a — done.**
* **Next firm step: Session 15 — Settings screen with Apple 4.3 disclosures, audio toggle stub, and How to Play content.**

## Known Gaps and Tooling Needs

* Deterministic deal path / debug "force specific hand" affordance still applies as a needed tooling improvement to make hand-tier ceremonies, fold paths, and edge cases easier to reproduce on demand.

## Sustainability Check

Three sessions in close succession (11, 14, 14a). 14a was a recovery-jog bug-fix session, not a rest day. **Tomorrow is a real phone test day, not a build day.** Then Session 15.

## Session 14b notes

**Session 14b — Housekeeping (no commit).** Dropped stale `main-pbxproj-reorder-pre-session14-merge` stash. Audited dealer-card view identity pattern: **finding — dealer cards are missing both halves of the per-deal SwiftUI identity convention** (no `.id("dealer-card-...")` on the dealer `CardView`s in `GameTableView.swift`, and no `await Task.yield()` at the top of `animateDealerHoleCards` in `GameTableViewModel.swift`). Deferred to a focused follow-up session per the same reasoning that produced Session 14a — dealer face-down state interacts with fold path and Session 11's no-reveal rule, so it deserves regression tests, not a drive-by. Updated handoff doc. Confirmed simulator plist shows starter-bonus-applied state (`chipBalance = 0`, `starterBonus = 1`).
