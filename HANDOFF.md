# 6th Seat Hold'em — Session Handoff

Running session log: what shipped, what's next, open items. Updated every session. Architectural decisions live in `SPEC.md`. This file is operational state only.

**Last updated:** 2026-04-28 (Session 15a)

**Project completion estimate:** ~92% complete (was ~88%)

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

(Earlier sessions 1–11 are reconstructable from `git log --oneline` on `main`.)

## Current File Inventory (post-Session 15a)

App/Views additions and annotations:

* `MainMenuView.swift` (encloses `MenuDestination` enum + `MainMenuLogic` helpers)
* `SettingsView.swift` (Session 15a — Form-based screen with three sections: Audio & Haptics toggles, Legal & Disclosures with hosted GitHub Pages links, About with bundle version. `SettingsLinks` exposes the privacy/terms URLs and version-string formatter for tests)
* `ChipShopView.swift` (Session 12b stub upgrade + Session 15a no-cash-value line; real IAP in Session 16)
* `HowToPlayView.swift` (Session 15a — single scrollable rules reference with engine-sourced paytables. `HowToPlayCopy.blindRows` / `tripsRows` derive from `UTHRules.blindPaytable` / `tripsPaytable` so spec/UI cannot drift)
* `BustFlashView.swift` (Session 12b — in-game flash modal; first-bust gift, second-bust Chip Shop routing)
* `DisclosureModalView.swift` (Session 15a — Apple 4.3 first-launch entertainment-only disclosure. `DisclosureCopy` shares the title/body strings with the Settings legal section)

App/ViewModels additions:

* `GatedHapticsService.swift` (Session 15a — wrapper over any `HapticsService` that reads `PersistenceKeys.settingsHapticsEnabled` at the call site. Default-on. Production `GameTableViewModel.init` wraps `SystemHapticsService` in this gate)

Engine package additions:

* `UserDefaultsChipStore` (real production implementation, applies starter bonus eagerly on init)
* `PersistenceKeys.hasSeenDisclosure` (Session 15a — gates first-launch disclosure modal)
* `PersistenceKeys.settingsSFXEnabled` / `settingsAmbientEnabled` / `settingsHapticsEnabled` (Session 15a — `@AppStorage`-backed user preferences. SFX/ambient store-only until Session 17 audio integration; haptics gates immediately via `GatedHapticsService`)

App description note:

> `ContentView` is now a `NavigationStack` shell with a `GameDestinationView` wrapper that owns `GameTableViewModel` via `@State`. A `.fullScreenCover` over the menu presents `DisclosureModalView` on first launch — the cover's bound `@State` is initialized from `UserDefaults.standard.bool(forKey: PersistenceKeys.hasSeenDisclosure)` at struct init so the modal renders on the very first body pass without a one-frame uncovered menu flash.

## Workflow Lessons

* Start every session with: `git checkout main && git pull && git log --oneline -5`. Confirm latest commit matches expectation before doing anything else. For bug-fix sessions, also verify the reported bug reproduces locally before fixing — don't fix what isn't broken on the current build.

## Open Items / Housekeeping

**Phone test pending across Sessions 11/14/14a/12/15a.** Items to feel for:

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

**Deferred (asset-blocked or later session):**

* Chip balance updates immediately on bet placement, before card reveal. Surfaced in post-Session 12 phone test. Current behavior is functionally correct (chips committed to the wager) but visually thin because there is no chip-stack visual on the bet zone — chips appear to vanish from the balance with nothing on the felt to show where they went. Fix is to add chip-stack visuals on bet zones during Session 18 (Fiverr asset integration), at which point the balance number dropping becomes visually consistent with chips having physically moved onto the table. Do not stopgap before real assets land — placeholder chip visuals will feel worse than the current state.
* **Bet zone cycle ranges deferred to Session 15b.** Current Ante cycle is $5 → $25 → $100 → $500 → $1,000 → $0 with no $10 option. Real Vegas tables expose different cycle ranges based on table minimums ($10 tables include $10/$15 bets, $25 tables minimum at $25, etc.). When Session 15b ships table selection UI, both the Ante and Trips cycles should become table-aware. The chip-set authenticity question ($10 as a real chip vs. as a stack of two $5s) also resolves in Session 15b's context. Session 15a explicitly held this back from scope to keep the submission-readiness window short.
* **Hand-result payout display opacity (deferred to Session 15b or later).** When a hand resolves with mixed paytables (Blind 3:2, Trips 6:1, Ante and Play 1:1), the headline payout number bears no obvious relationship to the four bets placed. The math is correct (verified to the penny against Vegas paytables) but the display does not show its work. Real fix: hand-complete UI should break out the four resolutions individually before showing the total. Example layout:
    ```
    ANTE WIN  +$25
    BLIND WIN +$37 (3:2)
    PLAY WIN  +$100
    TRIPS     +$30 (6:1)
    ─────────────────
    TOTAL     +$192
    ```
    Surfaced post-Session 12d phone test. Defer to Session 15b or later UX polish pass.
* **Chip denomination constants partially centralized.** Session 12d introduced `GameConstants.minimumChipValue` (= 5) and `GameConstants.minimumPlayableBalance` (= 2 × minimum) in the engine package, and wired them through the bust threshold, `MainMenuLogic` thresholds, and the new affordability gates. The `anteCycle` (`[5, 25, 100, 500, 1000, 0]`) and `tripsCycle` (`[0, 5, 10, 25]`) literals in `GameTableViewModel.swift` still hard-code the raw amounts. Session 15b's table-aware cycle work is the natural place to fold those into a constants table.
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
* **Next firm step: Session 15b — Table selection + table-aware cycle ranges + payout breakdown display.** Also folds the `anteCycle` / `tripsCycle` literals in `GameTableViewModel.swift` into the centralized `GameConstants` table. Real Chip Shop with StoreKit IAP ships in Session 16.

## Known Gaps and Tooling Needs

* Deterministic deal path / debug "force specific hand" affordance still applies as a needed tooling improvement to make hand-tier ceremonies, fold paths, and edge cases easier to reproduce on demand.

## Sustainability Check

Sessions 11, 14, 14a, 12 in close succession. Session 12 was reactive to phone-test feedback rather than a planned slot — it reversed the earlier "struck" decision because the casino-realism issue read as more important on hardware than on paper. Real next step is a phone test pass on the new deal sequence + the still-outstanding dealer view-identity work (14c), then Session 15.

## Session 14b notes

**Session 14b — Housekeeping (no commit).** Dropped stale `main-pbxproj-reorder-pre-session14-merge` stash. Audited dealer-card view identity pattern: **finding — dealer cards are missing both halves of the per-deal SwiftUI identity convention** (no `.id("dealer-card-...")` on the dealer `CardView`s in `GameTableView.swift`, and no `await Task.yield()` at the top of `animateDealerHoleCards` in `GameTableViewModel.swift`). Deferred to a focused follow-up session per the same reasoning that produced Session 14a — dealer face-down state interacts with fold path and Session 11's no-reveal rule, so it deserves regression tests, not a drive-by. Updated handoff doc. Confirmed simulator plist shows starter-bonus-applied state (`chipBalance = 0`, `starterBonus = 1`).
