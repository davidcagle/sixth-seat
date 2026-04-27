# 6th Seat Hold'em — Session Handoff

Running session log: what shipped, what's next, open items. Updated every session. For locked design decisions, paytables, and architecture, see `SPEC.md`.

**Last updated:** 2026-04-27 (Session 14c-prep-2)

**Project completion estimate:** ~78% complete (was ~75%)

## Project History

| Session | Summary | Net lines |
|---|---|---|
| 14 | Main Menu screen + NavigationStack routing + persistent ChipStore | 224 |
| 14a | Bug fixes: bonus stacking on first launch, community cards face-down regression | 232 |

(Earlier sessions 1–11 are reconstructable from `git log --oneline` on `main`.)

## Current File Inventory (post-Session 14a)

App/Views additions and annotations:

* `MainMenuView.swift` (encloses `MenuDestination` enum + `MainMenuLogic` helpers)
* `SettingsView.swift` (stub — Session 15)
* `ChipShopView.swift` (stub — Session 16)
* `HowToPlayView.swift` (stub — Session 15)

Engine package additions:

* `UserDefaultsChipStore` (real production implementation, applies starter bonus eagerly on init)

App description note:

> `ContentView` is now a `NavigationStack` shell with a `GameDestinationView` wrapper that owns `GameTableViewModel` via `@State`.

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
