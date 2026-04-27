# 6th Seat Hold'em — Session Handoff

Running session log: what shipped, what's next, open items. Updated every session. For locked design decisions, paytables, and architecture, see `SPEC.md`.

**Last updated:** 2026-04-27 (Session 12b)

**Project completion estimate:** ~86% complete (was ~84%)

## Project History

| Session | Summary | Net lines |
|---|---|---|
| 14 | Main Menu screen + NavigationStack routing + persistent ChipStore | 224 |
| 14a | Bug fixes: bonus stacking on first launch, community cards face-down regression | 232 |
| 12 | Deal all 5 community cards face-down up front; flip on phase transitions instead of phase deal | 238 |
| 14c | Apply view-identity pattern to dealer hole cards (`.id()` + `Task.yield()`) | 242 |
| 12a | Unify Ante bet zone to tap-to-cycle (parity with Trips); remove +/- stepper | 250 |
| 12b | In-game bust flow: first-bust gift modal awards 2,500 chips, second-bust modal routes to Chip Shop; Chip Shop stub upgraded with back-to-menu | 267 |

(Earlier sessions 1–11 are reconstructable from `git log --oneline` on `main`.)

## Current File Inventory (post-Session 14a)

App/Views additions and annotations:

* `MainMenuView.swift` (encloses `MenuDestination` enum + `MainMenuLogic` helpers)
* `SettingsView.swift` (stub — Session 15)
* `ChipShopView.swift` (Session 12b stub upgrade — title + "coming soon" line + Back to Menu button; real IAP in Session 16)
* `HowToPlayView.swift` (stub — Session 15)
* `BustFlashView.swift` (Session 12b — in-game flash modal; first-bust gift, second-bust Chip Shop routing)

Engine package additions:

* `UserDefaultsChipStore` (real production implementation, applies starter bonus eagerly on init)

App description note:

> `ContentView` is now a `NavigationStack` shell with a `GameDestinationView` wrapper that owns `GameTableViewModel` via `@State`.

## Architectural Decisions

* Bust detection fires in-game at the moment chip resolution lands balance at 0, not at the menu boundary. First bust awards 2,500 second-chance chips with a brand-voiced flash modal. Second bust routes to Chip Shop via flash modal with navigation button. The `hasReceivedSecondChanceBonus` flag is set at moment of award (before modal display) to protect against force-quit replay. The Session 14 menu-boundary check remains as a fallback. (Session 12b)

(Also see `SPEC.md` for the full set of architectural decisions established in earlier sessions.)

## Workflow Lessons

* Start every session with: `git checkout main && git pull && git log --oneline -5`. Confirm latest commit matches expectation before doing anything else. For bug-fix sessions, also verify the reported bug reproduces locally before fixing — don't fix what isn't broken on the current build.

## Open Items / Housekeeping

**Phone test pending across Sessions 11/14/14a/12.** Items to feel for:

1. Tier 3 timing at 2400ms — does it breathe or did we overshoot?
2. Royal-flush triple-tap distinctness on hardware (V1.5 fallback to `CHHapticEngine` if it reads as fuzzy buzz)
3. Fold-loop pacing — Vegas-pace or jarring?
4. Tier 1 flatness — confirm Session 11's polish fixed it (probably yes, but verify)
5. Main Menu visuals + button readability + navigation flow
6. Second-chance bonus flow on hardware: drive balance to 0, confirm bonus fires correctly on Play tap (not on entry, not stacked)
7. Verify community-card face-down deal works correctly across multiple consecutive hands (the Session 14a regression repro path)
8. **(Session 12) Casino-feel of the new deal sequence**: do all 5 community cards visibly arrive face-down at DEAL? Does the burn pause feel like stillness rather than waiting? Do the flip stutters / view-identity edge cases the auto tests can't catch read clean?

**Deferred (asset-blocked or later session):**

* Chip balance updates immediately on bet placement, before card reveal. Surfaced in post-Session 12 phone test. Current behavior is functionally correct (chips committed to the wager) but visually thin because there is no chip-stack visual on the bet zone — chips appear to vanish from the balance with nothing on the felt to show where they went. Fix is to add chip-stack visuals on bet zones during Session 18 (Fiverr asset integration), at which point the balance number dropping becomes visually consistent with chips having physically moved onto the table. Do not stopgap before real assets land — placeholder chip visuals will feel worse than the current state.
* **Bet zone cycle ranges deferred to Session 15.** Current Ante cycle is $5 → $25 → $100 → $500 → $1,000 → $0 with no $10 option. Real Vegas tables expose different cycle ranges based on table minimums ($10 tables include $10/$15 bets, $25 tables minimum at $25, etc.). When Session 15 ships table selection UI, both the Ante and Trips cycles should become table-aware. The chip-set authenticity question ($10 as a real chip vs. as a stack of two $5s) also resolves in Session 15's context.

## What's Next

* **Session 12 — done.** Reversed from "struck" after 2026-04-27 phone test surfaced casino-realism gap (community cards animating in face-down at phase, instead of being pitched out at hand start).
* **Session 14 — done.**
* **Session 14a — done.**
* **Session 14c — done.** Dealer hole cards now carry the `.id("dealer-card-\(currentDealId)-N")` modifier and `animateDealerHoleCards` opens with `await Task.yield()`, completing Project Convention #4 across all card slots.
* **Session 12a — done.** Ante bet zone now uses tap-to-cycle ($5 → $25 → $100 → $500 → $1,000 → $0) mirroring the Trips zone. Removed the +/- stepper UI and the `incrementStagedAnte` / `decrementStagedAnte` / `anteSteps` model surface entirely. Blind continues to mirror Ante automatically (engine invariant in `placeAnte`), and DEAL is now disabled when the cycle lands on $0.
* **Session 12b — done.** Bust detection moved in-game. After chip resolution lands the balance at zero, a brand-voiced flash modal fires: first bust awards 2,500 chips with a `.success` haptic and resets the table to `.awaitingBets` with Ante = $5 behind the modal; second bust uses a `.warning` haptic and routes to the Chip Shop via path replacement (`path = [.chipShop]`). The `hasReceivedSecondChanceBonus` flag is set at the moment of award, *before* the modal is shown, so a force-quit during the modal cannot replay the bonus. Chip Shop stub upgraded with title, "Chip bundles coming soon." line, and a Back to Menu button. The Session 14 menu-boundary check stays in place as a fallback.
* **Next firm step: Session 15 — Settings + Apple 4.3 disclosures + How to Play content.** Also resolves table-aware bet zone cycle ranges (currently deferred). Real Chip Shop with StoreKit IAP ships in Session 16.

## Known Gaps and Tooling Needs

* Deterministic deal path / debug "force specific hand" affordance still applies as a needed tooling improvement to make hand-tier ceremonies, fold paths, and edge cases easier to reproduce on demand.

## Sustainability Check

Sessions 11, 14, 14a, 12 in close succession. Session 12 was reactive to phone-test feedback rather than a planned slot — it reversed the earlier "struck" decision because the casino-realism issue read as more important on hardware than on paper. Real next step is a phone test pass on the new deal sequence + the still-outstanding dealer view-identity work (14c), then Session 15.

## Session 14b notes

**Session 14b — Housekeeping (no commit).** Dropped stale `main-pbxproj-reorder-pre-session14-merge` stash. Audited dealer-card view identity pattern: **finding — dealer cards are missing both halves of the per-deal SwiftUI identity convention** (no `.id("dealer-card-...")` on the dealer `CardView`s in `GameTableView.swift`, and no `await Task.yield()` at the top of `animateDealerHoleCards` in `GameTableViewModel.swift`). Deferred to a focused follow-up session per the same reasoning that produced Session 14a — dealer face-down state interacts with fold path and Session 11's no-reveal rule, so it deserves regression tests, not a drive-by. Updated handoff doc. Confirmed simulator plist shows starter-bonus-applied state (`chipBalance = 0`, `starterBonus = 1`).
