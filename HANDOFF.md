# 6th Seat Hold'em — Session Handoff

Running session log: what shipped, what's next, open items. Updated every session. Architectural decisions live in `SPEC.md`. This file is operational state only.

**Last updated:** 2026-05-05 (Session 17)

**Project completion estimate:** ~97% complete

## Session Prompt Standards — Required Boilerplate

Every session prompt written by Claude (in chat) for Claude Code (desktop) must include the start-of-session and end-of-session blocks below. These are non-negotiable workflow standards established across Sessions 1–15. Without them, Claude Code improvises and tells the user to run merge commands manually, which is a regression.

**START-OF-SESSION** (paste verbatim into every prompt):

- git checkout main
- git pull
- git log --oneline -5
- Confirm <expected HEAD commit> is HEAD on main. If not, STOP and report.
- If pbxproj is dirty (Xcode bookkeeping reorder), run `git restore SixthSeat.xcodeproj/project.pbxproj` before continuing
- Verify working tree is clean: `git status` should show "nothing to commit, working tree clean"

**END-OF-SESSION** (paste verbatim into every prompt):

- Run all tests on both targets:
  - cd to engine package, run `swift test`, confirm engine count passing
  - Run `xcodebuild test` for the AppTests target, confirm app count passing
  - Combined total reported
- Build for iOS simulator, manually verify build succeeds (visual hardware verification will be done by David post-merge)
- Commit cleanly with descriptive message
- Manually merge to main with explicit commands (do not rely on the SessionEnd hook):
  - `git checkout main`
  - `git merge claude/<this-branch> --ff-only`
  - `git worktree remove <this worktree>`
  - `git branch -d claude/<this-branch>`
  - Confirm `git log` shows the new commit on main
  - Report the merge log
- Push to GitHub:
  - `git push`
  - Report any errors
- Report results, including:
  - Final test count (combined and per-target)
  - Confirmation of all `HANDOFF.md` / `SPEC.md` updates landed
  - Merge log
  - Push confirmation
  - Anything noteworthy from `/plan`
  - Any edge cases or latent-invariant findings

**WHY THIS MATTERS**

Claude Code handles its own merges. The user does not run merge commands manually. If a session prompt is missing this block, Claude Code may default to leaving the work on a worktree branch and asking the user to drive the merge — a workflow regression. Always include both blocks.

## Project History

| Session | Summary | Net lines |
|---|---|---|
| 14 | Main Menu screen + NavigationStack routing + persistent ChipStore | 224 |
| 14a | Bug fixes: bonus stacking on first launch, community cards face-down regression | 232 |
| 12 | Deal all 5 community cards face-down up front; flip on phase transitions instead of phase deal | 238 |
| 14c | Apply view-identity pattern to dealer hole cards (`.id()` + `Task.yield()`) | 242 |
| 12a | Unify Ante bet zone to tap-to-cycle (parity with Trips); remove +/- stepper | 250 |
| 12b | In-game bust flow: first-bust gift modal awards 2,500 chips, second-bust modal routes to Chip Shop; Chip Shop stub upgraded with back-to-menu | 267 |
| 12c | Doc cleanup: consolidate architectural decisions to `SPEC.md`, record latent-invariant audit pattern as a Workflow Lesson | 267 |
| 12d | Affordability gates and bust threshold correctness: DEAL gated on 6× Ante (worst-case main bet), Trips force-cleared when unaffordable, bust threshold raised to `minimumPlayableBalance` (2× minimum chip = $10) | 282 |
| 15a | Submission-ready surfaces: first-launch Apple 4.3 disclosure modal, real Settings screen (audio/haptics/legal/about), real How to Play screen with engine-sourced paytables, Chip Shop no-cash-value reinforcement | 311 |
| 15b | Table selection UI + table-aware cycle ranges via `TableConfig` (engine), per-bet payout breakdown on hand-result UI, centralized cycle constants | 361 |
| 15c | Revert 15b's per-bet payout breakdown after hardware-test feedback; hand-result UI now shows a single colored net-result number (`+$N` green / `-$N` red / `Push` neutral) | 351 |
| 16 | Real Chip Shop with StoreKit 2 IAP. Five consumable tiers, per-install first-purchase doubler, restore button, persistent transaction listener. Engine-fronted IAP service + processor + telemetry (all SwiftUI-free); local Configuration.storekit for simulator testing. | 411 |
| 17 | Asset pipeline scaffolding. AssetService protocol + BundleAssetService + InMemoryAssetService, 83-slot placeholder asset catalog (52 cards + 1 back + 5 chips + 25 stack variants), engine-side StackHeight enum with bestFit rounder, CardView/ChipView/ChipStackView consume assets via SwiftUI environment. Drop-in ready for the Fiverr Phase-1 PNGs. | 433 |

(Earlier sessions 1–11 are reconstructable from `git log --oneline` on `main`.)

## Current File Inventory (post-Session 17)

App/Views additions and annotations:

* `CardView.swift` (Session 17 — slot-based renderer, consumes `AssetService` via `\.assets` SwiftUI environment. Signature switched from `faceDown: Bool` to `faceUp: Bool` to match the Session 17 prompt; existing call sites in `GameTableView` negate the view-model's `isXCardFaceDown(index:)` accessors at the boundary. Empty-slot rendering (when `card == nil`) is unchanged dashed outline; face/back rendering now resizes the named asset image (`card_<suit>_<rank>.png` / `card_back.png`) inside a rounded clip. The Y-axis flip animation and per-deal `.id("...")` view-identity convention are preserved.)
* `ChipStackView.swift` (Session 17 — signature changed from `amount: Int` to `(denomination: Int, count: Int)`. Reads `\.assets` environment, picks variant via `StackHeight.bestFit(for: count)`, renders `stack_<denomination>_h<height>.png`.)
* `ChipView.swift` (Session 17 — new view. `denomination: Int` parameter, reads `\.assets`, renders `chip_<denomination>.png`.)
* `MainMenuView.swift` (encloses `MenuDestination` enum + `MainMenuLogic` helpers; PLAY now routes to `.tableSelect` instead of straight to the game)
* `TableSelectView.swift` (Session 15b — three-card picker reading `TableConfig.all`. `TableSelectLogic.canEnter` / `allTablesUnaffordable` / `resolveLastPlayed` are pure helpers exposed for tests. Persists `PersistenceKeys.selectedTableID` via `@AppStorage` on tap, before the navigation push)
* `GameTableView.swift` (Session 15c — `.handComplete` headline restored to a single signed `+$N` / `-$N` / `Push` Text colored green / red / white off `HandResultHeadline.tone(for:)`. The `HandResultHeadline` enum is a pure helper at the bottom of the file, exposed for unit tests so the tone/text mapping can be asserted without rendering SwiftUI)
* `SettingsView.swift` (Session 15a — Form-based screen with three sections: Audio & Haptics toggles, Legal & Disclosures with hosted GitHub Pages links, About with bundle version. `SettingsLinks` exposes the privacy/terms URLs and version-string formatter for tests)
* `ChipShopView.swift` (Session 16 — replaced the stub with the real shop. Header shows current chip balance, doubler banner renders while `hasMadeFirstPurchase == false`, five tier cards iterate `viewModel.bundles` rendering doubled / strikethrough amounts via `ChipShopLogic`, per-card buy button shows StoreKit-localized price (or a spinner during purchase, or an inline error on failure), Restore Purchases button at bottom, no-cash-value reinforcement line and Back to Menu retained. View is dumb — every behavior lives in `ChipShopViewModel`. Stable identifiers: `ChipShop.Balance`, `ChipShop.DoublerBanner`, `ChipShop.Buy.<id>`, `ChipShop.Amount.<id>`, `ChipShop.Strikethrough.<id>`, `ChipShop.Badge.<id>`, `ChipShop.Error.<id>`, `ChipShop.Restore`, `ChipShop.RestoreMessage`, `ChipShop.NoCashValue`, `ChipShop.BackToMenu`.)
* `HowToPlayView.swift` (Session 15a — single scrollable rules reference with engine-sourced paytables. `HowToPlayCopy.blindRows` / `tripsRows` derive from `UTHRules.blindPaytable` / `tripsPaytable` so spec/UI cannot drift)
* `BustFlashView.swift` (Session 12b — in-game flash modal; first-bust gift, second-bust Chip Shop routing)
* `DisclosureModalView.swift` (Session 15a — Apple 4.3 first-launch entertainment-only disclosure. `DisclosureCopy` shares the title/body strings with the Settings legal section)

App/ViewModels additions:

* `GameTableViewModel.swift` (Session 15b — accepts `TableConfig` at init, default `.table10`. `anteCycle` / `tripsCycle` are computed off `tableConfig`; `stagedAnte` initializes to `tableConfig.minimumAnte`. The Trips zone affordability gate reads `tableConfig.minimumTripsStep` instead of a global `minimumChipValue`. First-bust reset uses `tableConfig.minimumAnte` instead of a hardcoded `5`)
* `GatedHapticsService.swift` (Session 15a — wrapper over any `HapticsService` that reads `PersistenceKeys.settingsHapticsEnabled` at the call site. Default-on. Production `GameTableViewModel.init` wraps `SystemHapticsService` in this gate)
* `ChipShopViewModel.swift` (Session 16 — `@Observable @MainActor` view model. Owns the displayed bundles array (initialized to `ChipBundleCatalog.all` so the screen renders immediately, refreshed in-place by `loadProductsIfNeeded()`), per-bundle loading + error state, balance + `hasMadeFirstPurchase` mirror, restore state. `purchase`/`restore` route into the injected `IAPService`. `displayAmount` / `strikethroughAmount` / `doublerActive` derive from `ChipShopLogic` so the doubler math is testable without rendering SwiftUI. Concurrent purchase taps are dropped at the boundary (`loadingBundleID` guard); an additional engine-level dedupe via `processedTransactionIDs` is the load-bearing safety net.)
* `AssetService.swift` (Session 17 — App layer service. Defines the `AssetService` protocol (`Sendable`), `AssetNames` pure name-mapping helper, `BundleAssetService` (production, returns `Image(<name>)`), and `InMemoryAssetService` (`@unchecked Sendable` test double that records every request and returns SF Symbol images). Also defines the SwiftUI `\.assets` environment value with `BundleAssetService()` as the default. Lives alongside `HapticsService` / `SystemHapticsService` / `GatedHapticsService` in `App/ViewModels/` to match the existing service-injection pattern.)

Engine package additions:

* `TableConfiguration.swift` (Session 15b — `TableConfig` struct: `Equatable`, `Hashable`, `Codable`, `Identifiable`, `Sendable`. Three V1 tables (`.table10` / `.table25` / `.table50`) and helpers (`minimumEntryBalance`, `minimumTripsStep`, `anteRangeDescription`, `table(forID:)`). Single source of truth for cycle data — the app reads cycles from a `TableConfig` instance, never inline literals)
* `UserDefaultsChipStore` (real production implementation, applies starter bonus eagerly on init)
* `PersistenceKeys.hasSeenDisclosure` (Session 15a — gates first-launch disclosure modal)
* `PersistenceKeys.settingsSFXEnabled` / `settingsAmbientEnabled` / `settingsHapticsEnabled` (Session 15a — `@AppStorage`-backed user preferences. SFX/ambient store-only until Session 17 audio integration; haptics gates immediately via `GatedHapticsService`)
* `PersistenceKeys.selectedTableID` (Session 15b — last-played `TableConfig.id`. Default-handling lives in `TableConfig.table(forID:)`; an unset or unknown id resolves to `TableConfig.defaultTable`)
* `ChipBundle.swift` + `BundleBadge` (Session 16 — `Equatable, Hashable, Codable, Identifiable, Sendable` struct. Engine ships placeholder `localizedPrice` strings; the IAP service substitutes `Product.displayPrice` at runtime. `BundleBadge.label` exposes the human-readable accent string so the engine can stay SwiftUI-free while the app maps to colors.)
* `ChipBundleCatalog.swift` (Session 16 — single source of truth for the five V1 bundles in display order. `all`, `allProductIDs`, `bundle(forID:)` helpers. Product IDs MUST match App Store Connect exactly — see Open Items.)
* `ChipPurchaseProcessor.swift` (Session 16 — pure credit pipeline owning the three IAP business invariants: idempotency (processed-set guard), first-purchase doubler (flag flipped BEFORE credit per force-quit safety pattern), restore-never-doubles. Both production and test-double IAP services route through this so the test double cannot drift.)
* `IAPService.swift` (Session 16 — protocol + `PurchaseResult` + `IAPError` + `InMemoryIAPService` test double. `Sendable`. Test double is configurable per call: scripted `Scripted` enum drives success / userCancelled / pending / verificationFailure / networkError paths. Captures call counters and routes success through `ChipPurchaseProcessor` so test asserts can verify both VM and engine behaviors end-to-end.)
* `StoreKitIAPService.swift` (Session 16 — production. `import StoreKit`. `loadProducts` resolves prices via `Product.products(for:)`. `purchase` walks the StoreKit 2 `Product.PurchaseResult` → `VerificationResult<Transaction>` flow and credits via `ChipPurchaseProcessor` before calling `transaction.finish()`. `restore` calls `AppStore.sync()` then sweeps `Transaction.unfinished` with `isRestore: true`. `startTransactionListener` runs a long-lived `Task` over `Transaction.updates` so purchases that complete outside the active session credit chips on next launch.)
* `TelemetryService.swift` (Session 16 — protocol + `LoggingTelemetryService` (writes to `OSLog` for sandbox debugging) + `RecordingTelemetryService` (in-memory test double). Hooks: `purchase_initiated`, `purchase_succeeded(isFirstPurchase:)`, `purchase_failed(reason:)`, `restore_initiated`, `restore_completed(count:)`. TelemetryDeck wiring is Session 17 — protocol exists now to keep the IAP service from painting itself into a corner.)
* `ChipShopLogic.swift` (Session 16 — pure helpers backing the Chip Shop UI: `bannerText`, `doublerActive(hasMadeFirstPurchase:)`, `displayAmount(for:doublerActive:)`, `strikethroughAmount(for:doublerActive:)`, `formatChipAmount`, `restoreMessage(restoredCount:)`. Used by both the view model and asserted directly in engine tests so doubler math is unit-testable without rendering SwiftUI.)
* `ChipStoreProtocol.hasMadeFirstPurchase` and `ChipStoreProtocol.processedTransactionIDs` (Session 16 — new properties + UserDefaults backing. `processedTransactionIDs` is encoded as `[String]` (sorted on write for stable storage shape) and re-materialized as `Set<String>` on read. Both impls (`UserDefaultsChipStore` / `InMemoryChipStore`) are now `@unchecked Sendable` and the protocol is `Sendable` so the IAP service can mutate the store from a non-main isolation domain.)
* `PersistenceKeys.hasMadeFirstPurchase` and `PersistenceKeys.processedTransactionIDs` (Session 16 — IAP idempotency keys. `reset()` clears them alongside the chip-economy keys.)
* `StackHeight.swift` (Session 17 — public engine enum. Cases `.h1 / .h3 / .h5 / .h10 / .h20` mirror the Phase-1 stack art. `bestFit(for chipCount: Int) -> StackHeight` rounds down to the largest available variant ≤ count and clamps sub-1 counts to `.h1`. Pure integer arithmetic, no SwiftUI. Used by `ChipStackView` via `AssetService.chipStackImage(denomination:height:)`.)

App/Assets.xcassets additions:

* `Cards/` (Session 17 — 53 imagesets: `card_<suit>_<rank>.imageset` for each of 4 suits × 13 ranks plus `card_back.imageset`. Suits use lowercase tokens (`hearts/diamonds/clubs/spades`); ranks use numeric digits (`2`–`10`) and lowercased names (`jack/queen/king/ace`). Each imageset's `Contents.json` declares the expected designer filename; placeholder PNGs (24×24 solid colors per suit) are bundled so the asset compiler doesn't error on missing files. Drop-in path: replace each placeholder PNG with the designer's at the same filename — no Contents.json edits needed.)
* `Chips/` (Session 17 — 5 imagesets: `chip_5 / chip_25 / chip_100 / chip_500 / chip_1000`. Same placeholder + drop-in convention as Cards.)
* `ChipStacks/` (Session 17 — 25 imagesets: `stack_<denomination>_h<height>` for each of 5 denominations × 5 stack heights. Same placeholder + drop-in convention.)
* `tools/generate_placeholder_assets.py` (Session 17 — one-shot generator that created the catalog above. Re-runs overwrite imagesets in place; do NOT re-run after the designer's PNGs land or the real art will be clobbered.)

App description note:

> `ContentView` is now a `NavigationStack` shell with a `GameDestinationView` wrapper that owns `GameTableViewModel` via `@State`. The PLAY route is now `.tableSelect → .game(tableID:)` — the destination resolves the id back to a `TableConfig` via `TableConfig.table(forID:)` and hands it to the view model. A `.fullScreenCover` over the menu presents `DisclosureModalView` on first launch — the cover's bound `@State` is initialized from `UserDefaults.standard.bool(forKey: PersistenceKeys.hasSeenDisclosure)` at struct init so the modal renders on the very first body pass without a one-frame uncovered menu flash. (Session 16) `SixthSeatApp.init` constructs both `chipStore` and `StoreKitIAPService` and calls `iapService.startTransactionListener()` so the long-lived `Transaction.updates` task is alive for the entire process. `ContentView` carries the `iapService: IAPService` parameter alongside `chipStore`; the `.chipShop` destination instantiates a fresh `ChipShopViewModel` with the shared services. `Configuration.storekit` at the project root + `<StoreKitConfigurationFileReference>` in the iOS scheme lets the simulator transact against local products without an App Store Connect setup or sandbox tester account.

## Workflow Lessons

* Start every session with: `git checkout main && git pull && git log --oneline -5`. Confirm latest commit matches expectation before doing anything else. For bug-fix sessions, also verify the reported bug reproduces locally before fixing — don't fix what isn't broken on the current build.

## Open Items / Housekeeping

**Phone test pending across Sessions 11/14/14a/12/15a/15b/15c/16.** Sessions 15a, 15b, and 16 all shipped without an intervening hardware pass; 15c is a UX revert *driven by* a partial 15b hardware pass (the per-bet breakdown read as too busy on the phone). Sessions 15a/15b/15c/16 are bundled into one upcoming pass — flag any "stacked-untested-layer" surprises that fall out (the sequencing note from Session 16's prompt). Items to feel for:

1. Tier 3 timing at 2400ms — does it breathe or did we overshoot?
2. Royal-flush triple-tap distinctness on hardware (V1.5 fallback to `CHHapticEngine` if it reads as fuzzy buzz)
3. Fold-loop pacing — Vegas-pace or jarring?
4. Tier 1 flatness — confirm Session 11's polish fixed it (probably yes, but verify)
5. Main Menu visuals + button readability + navigation flow
6. Second-chance bonus flow on hardware: drive balance to 0, confirm bonus fires correctly on Play tap (not on entry, not stacked)
7. Verify community-card face-down deal works correctly across multiple consecutive hands (the Session 14a regression repro path)
8. **(Session 12) Casino-feel of the new deal sequence**: do all 5 community cards visibly arrive face-down at DEAL? Does the burn pause feel like stillness rather than waiting? Do the flip stutters / view-identity edge cases the auto tests can't catch read clean?
9. **(Session 15a) First-launch disclosure modal**: clear `PersistenceKeys.hasSeenDisclosure` (or reinstall), confirm the modal appears over the menu on first body pass with no one-frame uncovered menu flash, button is the only exit, second launch goes straight to the menu.
10. **(Session 15a) Settings haptics toggle**: turn off Haptics in Settings, return to game, confirm card flips and resolution haptics fall silent. Toggle back on, confirm they resume on the next hand.
11. **(Session 15a) Settings legal links**: tap Privacy Policy and Terms of Service, confirm they open the hosted GitHub Pages docs in Safari without crashing.
12. **(Session 15a) How to Play paytable readability**: scroll through the rules screen, confirm the two paytables render as actual rows (not prose) and the Vegas paytable values match the felt.
13. **(Session 15b) Table picker layout + tap targets**: walk through PLAY → table picker → game on each of the three tables. Confirm card minimum tap target is comfortable, "Last played" pill is legible, disabled-card visual reads as "unaffordable" (not "broken").
14. **(Session 15b) Persisted last-played table**: pick `.table25`, exit to menu, tap PLAY again — the picker should highlight the $25 card as "Last played". Force-quit and relaunch — same expectation.
15. **(Session 15c) Hand-result headline color + legibility**: play hands across outcomes (win, loss, true push) and confirm the single signed number reads clearly on the felt — green for `+$N`, red for `-$N`, white for `Push`. The 15b per-bet breakdown was reverted in 15c after the multi-line render felt too busy on a phone screen; verify the simpler headline doesn't read as too sparse the other way.
16. **(Session 15b) Table-specific cycle range entry**: at `.table25`, confirm the Ante zone tap-cycles `25 → 50 → 100 → 250 → 500 → 0`. At `.table50`, confirm Trips floor is $10 (not $5). At `.table10`, confirm $15 is now in the cycle (the gap from V1 / Session 14b feedback is closed).
17. **(Session 16) Chip Shop end-to-end**: from the menu and from a forced second-bust, route into the Chip Shop. Confirm all five tiles render with their StoreKit-localized prices (sourced from `Configuration.storekit` in the simulator). On a fresh install (`hasMadeFirstPurchase` cleared), confirm the yellow `2X CHIPS ON YOUR FIRST PURCHASE` banner is visible above the tiles, every tile shows the doubled chip count with the base count strikethrough beside it, and `Most Popular` / `Best Value` badges render on Table Stakes / Deep Stack respectively. Tap any tier — purchase sheet renders, complete it, observe the balance number tick up, the doubler banner disappear on the next render, and the strikethroughs vanish. Tap a second tier — credits at base amount. Tap Restore Purchases — button is responsive (count is 0 in a freshly cleared sim, but the affordance is mandatory for App Store review). Back to Menu still routes correctly.
18. **(Session 17) Asset pipeline placeholder visuals**: the table renders with new placeholder assets behind the existing flip-animation chrome. Card faces are now solid-color rectangles (red for hearts/diamonds, near-black for clubs/spades) and the back is a deep blue rectangle — both inside the existing rounded-corner clip. Confirm the deal sequence still walks through face-down → face-up correctly, the per-deal `.id("...")` reuse pattern still flips on the second hand, and all three card slot families (player, dealer, community) render without empty squares or broken-image markers. Chip placeholders are tiny solid-color discs; ChipView/ChipStackView aren't yet placed on the felt but render correctly in previews. Real visual sign-off comes after the Phase 1 designer drop — this pass is just to confirm the swap-out path didn't break the layout.

**App Store Connect IAP setup (David, manual).** Before Session 16's code can be tested in sandbox or TestFlight, the five products must be created in App Store Connect under Features → In-App Purchases → Consumable. For each: set product ID (matching the code's hardcoded IDs exactly — typo = silent failure), price tier, display name, description, English localization. Also set up at least one sandbox tester account under Users and Access → Sandbox → Testers. The StoreKit Configuration File added in Session 16 lets the simulator run purchases locally without this — but real sandbox testing on TestFlight requires it. Plan to do this between code completion and TestFlight upload. The five product IDs are hardcoded in `SixthSeat/Sources/SixthSeat/ChipBundleCatalog.swift`:

> `com.sixthseat.uth.chips.pocketchange` ($0.99, 5,000 chips)
> `com.sixthseat.uth.chips.starter` ($1.99, 25,000 chips)
> `com.sixthseat.uth.chips.tablestakes` ($4.99, 75,000 chips)
> `com.sixthseat.uth.chips.highroller` ($9.99, 250,000 chips)
> `com.sixthseat.uth.chips.deepstack` ($19.99, 750,000 chips)

**Deferred (asset-blocked or later session):**

* Chip balance updates immediately on bet placement, before card reveal. Surfaced in post-Session 12 phone test. Current behavior is functionally correct (chips committed to the wager) but visually thin because there is no chip-stack visual on the bet zone — chips appear to vanish from the balance with nothing on the felt to show where they went. Fix is to add chip-stack visuals on bet zones during Session 18 (Fiverr asset integration), at which point the balance number dropping becomes visually consistent with chips having physically moved onto the table. Do not stopgap before real assets land — placeholder chip visuals will feel worse than the current state.
* **Mid-game table switching (out for V1).** No in-game "change table" affordance — the player must back out to the menu and re-pick. Considered out of scope for V1 because mid-game switching needs to interleave with bet/deal/resolve. Revisit if hardware feedback says the menu round-trip feels heavy.
* **Trips-win legibility on the headline (revisit only if it surfaces).** Session 15c collapses the 15b per-bet breakdown back into a single signed net-result number. Trips wins lose their dedicated callout — the player sees the combined number rather than the trips paytable hit. Accepted tradeoff because the breakdown read as too busy on a phone screen. If hardware testing later surfaces "I don't know my Trips paid" as a real player-feel issue, address with a lighter-touch solution (a small per-side-bet badge or accent on the headline) rather than re-adopting the full breakdown.
* **Table-specific visual themes (V2).** All three tables share the same green felt and accent color in V1. Different felt tones / accent colors / chip art per table is a V2 polish opportunity that depends on the Fiverr asset drop landing first.
* **Variable starting bankroll based on table choice (V2).** Player gets the same 2,500-chip starter regardless of which table they picked first. Real-money rooms scale the buy-in to the table — V2 candidate.
* **Mid-game Settings access (Session 15a deferred).** No gear icon on the game table in V1. Players reach Settings only via the Main Menu Back path. Acceptable for V1 because in-game Settings would need its own modal/pause flow and would interleave with the bet/deal/resolve sequence. Revisit when Session 17 audio lands and players want a quick mute during a hand.

## What's Next

* **Session 12 — done.** Reversed from "struck" after 2026-04-27 phone test surfaced casino-realism gap (community cards animating in face-down at phase, instead of being pitched out at hand start).
* **Session 14 — done.**
* **Session 14a — done.**
* **Session 14c — done.** Dealer hole cards now carry the `.id("dealer-card-\(currentDealId)-N")` modifier and `animateDealerHoleCards` opens with `await Task.yield()`, completing Project Convention #4 across all card slots.
* **Session 12a — done.** Ante bet zone now uses tap-to-cycle ($5 → $25 → $100 → $500 → $1,000 → $0) mirroring the Trips zone. Removed the +/- stepper UI and the `incrementStagedAnte` / `decrementStagedAnte` / `anteSteps` model surface entirely. Blind continues to mirror Ante automatically (engine invariant in `placeAnte`), and DEAL is now disabled when the cycle lands on $0.
* **Session 12b — done.** Bust detection moved in-game. After chip resolution lands the balance at zero, a brand-voiced flash modal fires: first bust awards 2,500 chips with a `.success` haptic and resets the table to `.awaitingBets` with Ante = $5 behind the modal; second bust uses a `.warning` haptic and routes to the Chip Shop via path replacement (`path = [.chipShop]`). The `hasReceivedSecondChanceBonus` flag is set at the moment of award, *before* the modal is shown, so a force-quit during the modal cannot replay the bonus. Chip Shop stub upgraded with title, "Chip bundles coming soon." line, and a Back to Menu button. The Session 14 menu-boundary check stays in place as a fallback.
* **Session 12c — done.** Doc cleanup. The Architectural Decisions section was removed from `HANDOFF.md` (the prior 12b entry already lives in `SPEC.md`); per project convention, durable decisions live in `SPEC.md` and `HANDOFF.md` is operational state only. The latent-invariant audit pattern (recurring across Sessions 12, 12a, 12b) was promoted to a formal Workflow Lesson in `SPEC.md`. No code or test changes; test count remains 267.
* **Session 12d — done.** Affordability gates and bust threshold correctness. The bust trigger now fires when `chipBalance < GameConstants.minimumPlayableBalance` (= 2 × minimum chip value = $10), not just at exact zero — a player who lands at $5 after a fold can no longer be stranded. The DEAL button is gated on `chipBalance >= 6 × stagedAnte` (worst-case Ante + Blind + 4× pre-flop Play); below that the button greys out and the player cycles Ante down to find an affordable value. Trips is force-cleared and disabled when balance covers the worst-case main bet but not Trips on top, and re-enables (without auto-restoring a prior amount) when the player cycles Ante down enough. The Session 14 menu-boundary fallback uses the same threshold. New `GameConstants` enum in the engine package centralizes the minimum chip value and the playable threshold. Test count: 282 (124 engine + 158 app, +15 from Session 12c).
* **Session 15a — done.** Submission-ready surfaces for App Store review. Adds the first-launch Apple 4.3 disclosure modal (entertainment-only language, single "I Understand" button, non-dismissible by background tap, persists `PersistenceKeys.hasSeenDisclosure`). Replaces the Settings stub with a real Form-based screen (SFX/ambient/haptics toggles; legal section with informational copy and links to the hosted privacy policy + terms of service GitHub Pages docs from Session 12-prep; About section with bundle version). Replaces the How to Play stub with a single scrollable, sectioned reference whose two paytables source rows directly from `UTHRules.blindPaytable` and `UTHRules.tripsPaytable` — engine and UI cannot drift. New `GatedHapticsService` wraps any `HapticsService` and gates immediately on `PersistenceKeys.settingsHapticsEnabled` (default-on, read at the call site). Chip Shop stub gains a no-cash-value reinforcement line above the existing copy. Test count: 311 (124 engine + 187 app, +29 from Session 12d).
* **Session 15b — done.** Resolves the four deferred items called out at the end of Session 15a. (1) Adds `TableConfig` to the engine — `Equatable, Hashable, Codable, Identifiable, Sendable` — with three V1 tables (`.table10` / `.table25` / `.table50`) carrying their own `anteCycle` / `tripsCycle` / `minimumAnte`. The view model layer reads cycles off a `TableConfig` instance instead of inline literals; `GameTableViewModel.init` accepts a `TableConfig` (default `.table10`) and the Trips affordability gate now reads `tableConfig.minimumTripsStep`. (2) Adds `TableSelectView` between PLAY and the game; the route becomes `MainMenu → .tableSelect → .game(tableID:)`. The screen renders three cards with affordability gating (cards disable when `chipBalance < 6 × minimumAnte`), persists the chosen id under `PersistenceKeys.selectedTableID` via `@AppStorage`, and falls back to a Chip Shop button when no table is enterable. (3) **Shipped and reverted in 15c — see the 15c entry below.** (4) The `anteCycle` / `tripsCycle` literals in `GameTableViewModel.swift` are gone — both flow off `tableConfig` now. Test count: 361 (138 engine + 223 app, +50 from Session 15a). Per the latent-invariant Workflow Lesson, the cycle-walking and DEAL-gate boundary tests in `GameTableViewModelTests` were rewritten to track the new `.table10` defaults, and bust-flow tests now read the table minimum from `TableConfig.defaultTable.minimumAnte` rather than the old hardcoded `5`.
* **Session 15c — done.** Reverts the per-bet payout breakdown shipped in Session 15b after a partial hardware pass: the multi-line breakdown read as too busy on a phone screen. The `.handComplete` headline goes back to a single signed `+$N` / `-$N` / `Push` number, colored green / red / white off `HandResultHeadline.tone(for:)`. `HandResultHeadline` is a small pure helper at the bottom of `App/Views/GameTableView.swift` — a `Tone` enum and `tone(for:)` / `text(for:)` mappings — so the color/text behavior can be asserted from tests without rendering SwiftUI. Source of truth remains the engine's `BetResolution.HandResult.totalNet`; no engine changes. `App/Views/PayoutBreakdownView.swift` and `AppTests/PayoutBreakdownTests.swift` are deleted; the four pbxproj references are pruned. New `AppTests/HandResultHeadlineTests.swift` covers tone (win/loss/neutral), text formatting, and confirms the headline reads `result.totalNet` without recomputing it. Trips wins lose their dedicated callout in this version — accepted UX tradeoff, captured as a deferred item to revisit only if hardware feedback flags it. Test count: 351 (138 engine + 213 app, −10 from Session 15b: −15 breakdown tests, +5 headline tests).
* **Session 16 — done.** Real Chip Shop with StoreKit 2 IAP. Five consumable tiers (`pocketchange` $0.99 / `starter` $1.99 / `tablestakes` $4.99 / `highroller` $9.99 / `deepstack` $19.99), per-install first-purchase doubler (`hasMadeFirstPurchase` flag flipped *before* credit per the force-quit-safety pattern from Session 12b), idempotent crediting (persisted `processedTransactionIDs` set as the load-bearing defense against listener replay / restore re-emission / Family Sharing redelivery), `Transaction.updates` listener started at app launch, Restore Purchases affordance, telemetry stubs (no-op `LoggingTelemetryService` for now; TelemetryDeck wiring deferred). New engine files: `ChipBundle`, `ChipBundleCatalog`, `ChipPurchaseProcessor`, `IAPService` + `InMemoryIAPService`, `StoreKitIAPService`, `TelemetryService` + `LoggingTelemetryService` + `RecordingTelemetryService`, `ChipShopLogic`. New app file: `ChipShopViewModel` (`@Observable @MainActor`). `ChipShopView` rewritten with the real screen. New project file: `Configuration.storekit` at root, wired into the iOS scheme via `<StoreKitConfigurationFileReference>`. `SixthSeatApp.init` constructs the IAP service and starts the listener; `ContentView` carries `iapService: IAPService` and instantiates a fresh `ChipShopViewModel` on each `.chipShop` route. Test count: 411 (179 engine + 232 app, +60 from Session 15c — 41 engine + 19 app). Per the latent-invariant Workflow Lesson: existing `ChipStoreTests` updated for the new keys + `reset()`; existing `ChipShopView()` instantiations in `MainMenuViewTests` and `BustFlowTests` updated for the new view model param; `ChipStoreProtocol` becomes `Sendable` so the IAP service can mutate the store from a non-main isolation domain.
* **Session 17 — done.** Asset pipeline scaffolding. Goal: when the Fiverr Phase 1 PNGs land in 2-3 days, swapping `placeholder_*.png` for `card_hearts_ace.png` (etc.) is the *only* work needed for visual integration. Built three layers: (1) The asset catalog itself — 83 imagesets (`Cards/`, `Chips/`, `ChipStacks/`) with `Contents.json` files declaring the designer's expected filenames and 24×24 solid-color placeholder PNGs at those filenames so the catalog compiles without errors. Generator script at `.claude/scripts/generate_placeholder_assets.py` is one-shot, do not re-run post-designer-drop. (2) `AssetService` protocol + `BundleAssetService` (production, named-image lookup) + `InMemoryAssetService` (test double, records requests and returns SF Symbol placeholders) + `AssetNames` (pure name-mapping helper, asserted directly in `AssetNamesTests`). All injected via the SwiftUI `\.assets` environment value. (3) View refactors — `CardView` switched from `faceDown: Bool` to `faceUp: Bool` and now renders `assets.cardImage(for:)` / `assets.cardBack()` resized inside its existing flip animation; `ChipStackView` switched from `amount: Int` to `(denomination: Int, count: Int)` and routes through `StackHeight.bestFit(for: count)`; new `ChipView(denomination:)` renders single chips. `StackHeight` lives in the engine package because `bestFit(for:)` is pure integer arithmetic worth covering with engine tests. `GameTableView` call sites negate `viewModel.isXCardFaceDown(index:)` at the boundary so the view model surface is unchanged. Test count: 433 (184 engine + 249 app, +22 from Session 16: +5 engine for `StackHeight`, +17 app for `AssetNames` / `InMemoryAssetService` / `CardView` rendering / `ChipView`+`ChipStackView` rendering). Per project convention #4 the per-deal `.id("...")` modifiers and `Task.yield()` in animation entry points are preserved on every `CardView` slot.
* **Next firm step: hardware test pass for Sessions 15a + 15b + 15c + 16 together** (see "Phone test pending" items above, especially item 17 for the Chip Shop end-to-end). The Session 17 asset scaffolding is invisible to phone testing — placeholder PNGs render as solid suit-colored squares behind the existing card-back/face fallback, which is fine for stress-testing the betting flow. After hardware sign-off lands and the App Store Connect IAP setup is complete (see Open Items), TestFlight upload is unblocked. **Session 18 — audio integration + TelemetryDeck wiring**, parallel-tracked with the designer's Phase 1 PNG drop arriving in 2-3 days (drop-in replacement, no code changes expected).

## Known Gaps and Tooling Needs

* Deterministic deal path / debug "force specific hand" affordance still applies as a needed tooling improvement to make hand-tier ceremonies, fold paths, and edge cases easier to reproduce on demand.

## Sustainability Check

Sessions 11, 14, 14a, 12 in close succession. Session 12 was reactive to phone-test feedback rather than a planned slot — it reversed the earlier "struck" decision because the casino-realism issue read as more important on hardware than on paper. Real next step is a phone test pass on the new deal sequence + the still-outstanding dealer view-identity work (14c), then Session 15.

## Session 14b notes

**Session 14b — Housekeeping (no commit).** Dropped stale `main-pbxproj-reorder-pre-session14-merge` stash. Audited dealer-card view identity pattern: **finding — dealer cards are missing both halves of the per-deal SwiftUI identity convention** (no `.id("dealer-card-...")` on the dealer `CardView`s in `GameTableView.swift`, and no `await Task.yield()` at the top of `animateDealerHoleCards` in `GameTableViewModel.swift`). Deferred to a focused follow-up session per the same reasoning that produced Session 14a — dealer face-down state interacts with fold path and Session 11's no-reveal rule, so it deserves regression tests, not a drive-by. Updated handoff doc. Confirmed simulator plist shows starter-bonus-applied state (`chipBalance = 0`, `starterBonus = 1`).
