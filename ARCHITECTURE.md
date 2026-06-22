# NineTilesPuzzle — Architecture Overview

Snapshot of the current codebase structure, as of 2026-06-22. This is a descriptive
document — see this file's own §6 resolution below (and `ROADMAP.md` §6, kept in sync with
it) for how the "does mode-specific behavior need a shared abstraction" question was
revisited once Time Trial and Limited Moves both existed, and what would justify
revisiting it again.

## Tech stack

- SwiftUI, iOS only, dark-mode-locked (`.preferredColorScheme(.dark)`)
- `@Observable` classes for shared state (no `ObservableObject`/Combine)
- Swift Concurrency throughout (`async/await`, structured `Task`s) — no GCD
- Persistence: `UserDefaults` only, no SwiftData/CloudKit yet — but abstracted behind a
  `PersistenceStore` protocol (see below), so that's a non-disruptive future swap
- Swift Testing (not XCTest) for unit tests
- No third-party dependencies

## Directory layout

```
NineTilesPuzzle/
├── NineTilesPuzzleApp.swift        — @main, constructs the four stores below + SoundService
├── Models/
│   ├── GameSession.swift           — the game currently configured/in progress (see below)
│   ├── StatsStore.swift            — personal bests, games played, streaks (keyed by StatsKey)
│   ├── SettingsStore.swift         — app prefs unrelated to "which game": preview/streak
│   │                                  countdown durations, haptics, debug overlay
│   ├── AchievementsStore.swift     — achievement definitions, unlock checks, remote refresh
│   ├── PersistenceStore.swift      — protocol seam over UserDefaults (see below)
│   ├── StatsKey.swift              — Hashable(gridSize, gameMode) used by GameSession/StatsStore
│   ├── GameMode.swift              — enum: classic/slide/timeTrial/limitedMoves/zen/fog/chaos
│   ├── TimeTrialRules.swift        — pure constants/formulas: base time limit per grid size,
│   │                                  combo bonus/misplay penalty, score (see below)
│   ├── GauntletLadderRules.swift   — pure 10-stage table + ladder scoring (see below);
│   │                                  deliberately separate from TimeTrialRules.swift
│   ├── LimitedMovesRules.swift     — pure per-grid-size move budget table (see below)
│   ├── TileModel.swift             — @Observable tile: id, currentIndex, isLocked
│   ├── Achievement.swift           — Codable achievement definition + unlock flag
│   ├── ZenSparkle.swift            — decorative particle model for Zen mode's solve animation
│   ├── Bundle-Decodable-Ext.swift
│   ├── TimeInterval-Formatting-Ext.swift
│   └── Image/
│       ├── MediaSourceType.swift   — enum: random/local/mixed/numbers
│       ├── RemoteImageSource.swift — also declares the `ImageSource` protocol
│       ├── LocalImageSource.swift  — bundled fallback image
│       ├── PhotoLibraryImageSource.swift
│       └── ImageSourceError.swift
├── Services/
│   ├── GameEngine.swift            — protocol: shuffle() + shared isSolved()
│   ├── ClassicEngine.swift         — swap-any-two-tiles rules
│   ├── SlideEngine.swift           — 15-puzzle slide rules + solvability parity check
│   ├── SlideSolver.swift           — BFS solver, debug-only "Solve" button
│   ├── ImageService.swift          — primary/fallback source orchestration
│   ├── ImageSlicer.swift           — center-crop + slice CGImage into tile images
│   ├── SoundService.swift          — @Observable, AVAudioPlayer-backed SFX
│   └── AchievementService.swift    — bundled JSON + remote fetch + on-disk cache
├── Views/
│   ├── MenuView.swift               — root NavigationStack, routes via GameRoute enum
│   ├── StatsView.swift              — sheet: streaks, personal bests, games played
│   ├── AchievementsView.swift       — sheet: achievement list
│   ├── GameMode/GameModeView.swift  — mode picker + media source picker
│   ├── Settings/                    — SettingsView, GridSizePickerView, PreviewTimePickerView
│   ├── Streak/                      — StreakCounterView, StreakStatsView, StreakCountdownPickerView
│   ├── Puzzle/
│   │   ├── PuzzleView.swift                 — game screen orchestrator (mostly rendering now;
│   │   │                                      sequencing delegated to the view model below)
│   │   ├── PuzzleCompletionViewModel.swift  — completion banner, new-record badge timing,
│   │   │                                      drag-to-dismiss, Zen's breathe/sparkle sequence
│   │   ├── PuzzleGridView.swift     — tile layout, drag handling, slide/swap dispatch
│   │   ├── TileView.swift           — single draggable tile
│   │   ├── ImagePreviewView.swift   — pre-shuffle reveal
│   │   ├── PuzzleStatusBarView.swift, MoveCounterView.swift, TimeCounterView.swift
│   │   ├── TimeTrialTimerView.swift, TimeTrialScoreView.swift — Time Trial's HUD
│   │   ├── TimeTrialDeltaIndicatorView.swift — transient "+1s"/"-2s" combo indicator
│   │   ├── GauntletStageIndicatorView.swift — "Stage N of 10" HUD pill
│   │   ├── LimitedMovesCounterView.swift — Limited Moves' "N left" HUD pill, color-coded
│   │   │                                   by fraction of budget remaining
│   │   └── PuzzleErrorView.swift
│   └── Helpers/                     — grab-bag of small reusable views (toast, banners,
│                                       loading/splash, brand mark, badges, zen sparkle,
│                                       Time Trial's "Out of Time" overlay, Limited Moves'
│                                       "Out of Moves" overlay)
├── Resources/                       — achievements.json, sounds, asset catalog, app icon
NineTilesPuzzleTests/                 — real, wired-up Unit Testing Bundle target (see below)
```

## Core data flow

```
NineTilesPuzzleApp.init()
   constructs, in dependency order:
     StatsStore()  SettingsStore()  AchievementsStore()  ──▶  GameSession(stats:, achievements:, settings:)
   (each store defaults its `defaults:` param to UserDefaults.standard via PersistenceStore)
   injects all four + SoundService into the environment (app-wide singletons)
        │
        ▼
MenuView ── NavigationStack(GameRoute) ──▶ PuzzleView / GameModeView / StatsView / ...
        (each view reads only the store(s) it actually needs from the environment)
        │
        ▼
GameSession (@Observable, @MainActor)
   • owns: gridSize/mediaSourceType/selectedGameMode config, tiles, images, timers, live flags
   • owns instances of: ClassicEngine, SlideEngine
   • depends on (read-only): StatsStore, AchievementsStore, SettingsStore, PersistenceStore
   • talks directly to: PersistenceStore (its own keys), ImageService, ImageSlicer
        │
        ├─ selectedGameMode ──▶ activeEngine (computed: .slide → SlideEngine, else Classic)
        │                              │
        │                  shuffle() / isSolved()   (shared GameEngine protocol)
        │                  swap() / slide()         (mode-specific, called directly by GameSession)
        │
        └─ registerMove() reports completions/streaks to StatsStore, then asks
           AchievementsStore.checkAchievements(using: StatsStore) to re-evaluate unlocks
```

**Four stores, one dependency direction.** `GameSession` is the only one with dependencies
(`StatsStore`, `AchievementsStore`, `SettingsStore`, injected at init); the other three know
nothing about each other or about `GameSession`. This used to be a single god object
(`PuzzleState`) owning all five concerns — split in June 2026. Why the boundaries fell where
they did:
- **`GameSession`** owns `gridSize`/`mediaSourceType`/`selectedGameMode` (not `SettingsStore`)
  because changing them must synchronously clear the in-progress board — keeping that inside
  one type avoids needing cross-store reactive wiring.
- **`StatsStore`** doesn't know "current" anything (no grid size, no selected mode) — it only
  answers questions keyed by `StatsKey`. `GameSession` exposes the "for current size/mode"
  convenience accessors (`currentStreakForCurrentSize`, `classicBestMovesForCurrentSize`, …)
  since it's the one place that knows what "current" means.
- **`AchievementsStore.checkAchievements(using:)`** takes `StatsStore` as a parameter rather
  than holding a permanent reference, so it stays decoupled and easy to test with fake stats.

**`PersistenceStore`** (`Models/PersistenceStore.swift`) — a minimal protocol mirroring the
handful of `UserDefaults` methods the four stores actually use (`set`/`object`/`string`/
`data`/`integer`/`double`/`bool`/`removeObject`, all keyed by `String`). `UserDefaults`
conforms with no extra code; each store's `init` takes `defaults: PersistenceStore =
UserDefaults.standard`. This isn't a full repository/DAO layer — it's deliberately just
enough indirection that tests can swap in an in-memory fake (`InMemoryPersistenceStore`,
test-target-only) instead of touching real persisted app data, and it's the seam a future
SwiftData migration would slot behind.

**`PuzzleCompletionViewModel`** (`Views/Puzzle/PuzzleCompletionViewModel.swift`) — the
sequencing/timing logic that used to live directly in `PuzzleView`'s body and `onChange`/
`.task` handlers: the completion banner's lifetime and drag-to-dismiss gesture, how long
new-record badges stay visible, and Zen mode's breathe-and-fade transition into the next
puzzle. Takes no store dependencies — callers pass live values and closures per call — so
it's constructible and testable with zero environment setup.

**Game modes today**: `GameMode` is 7 cases; `isAvailable` now gates 5 of them (`.classic`,
`.slide`, `.zen`, `.timeTrial`, `.limitedMoves`), with the remaining 2 listed in the UI as
"Coming soon…" with no behavior. Mode-specific behavior is still expressed as scattered
conditionals (`isZenMode`, `isTimeTrialMode`, `isLimitedMovesMode`,
`selectedGameMode == .slide`, `settingsStore.debugOverlayEnabled`) inside `GameSession` and
`PuzzleView`/`PuzzleGridView` — see the §6 resolution below for why this stayed
conditionals-based even with Time Trial and Limited Moves as two structurally similar real
modes.

**Time Trial mode** (MVP scope — see `ROADMAP.md` §1 for what's deferred): one timed puzzle
per grid size, always on `ClassicEngine` (its per-move `isLocked` signal is what makes
"was this move correct?" detectable; `SlideEngine` never locks tiles, so Time Trial isn't
offered there). `GameSession` owns a third timer alongside the streak countdown and
stopwatch — `timeTrialRemaining`/`isTimeTrialRunning`/`isTimeTrialFailed` plus
`startTimeTrialCountdown()`/`stopTimeTrialCountdown()`, the same wall-clock-anchored `Task`
shape as `startCountdown()`/`stopCountdown()` — but with a *mutable* end date
(`timeTrialEndDate`) so `applyTimeTrialMoveOutcome(correctBefore:)` can nudge it on every
move: +1s on a move that locks a tile correctly, -2s otherwise, failing the puzzle if that
empties the clock. `Models/TimeTrialRules.swift` holds the pure, table-driven constants
(base time limit per grid size, the bonus/penalty amounts, the score formula) so they're
unit-testable with no `GameSession` dependency. `StatsStore` gained a `personalBestScore`
dictionary alongside `personalBestMoves`/`personalBestTime`, following the same
per-`StatsKey` shape. `PuzzleCompletionViewModel` gained `showNewTimeTrialScoreRecord` and
a `showTimeTrialFail` flag (driving a dedicated `TimeTrialFailView` "Out of Time" overlay,
mutually exclusive with the regular completion banner) alongside the existing record-badge
and Zen-sequence state.

**Gauntlet Ladder** (Time Trial sub-mode, shipped June 2026): a toggleable 10-stage
progression inside Time Trial — `GameSession.isLadderMode`, surfaced as a `Toggle` in
`GameModeView` only when `.timeTrial` is selected, not a separate `GameMode` case (it's the
same countdown/combo loop, just chained across stages with an escalating grid
size/time-limit/difficulty-multiplier table). `isGauntletLadderMode` (`isTimeTrialMode &&
isLadderMode`) gates every ladder-specific branch, so non-ladder Time Trial is provably
unaffected. `Models/GauntletLadderRules.swift` holds the 10-row stage table and a distinct
`stageScore(remainingSeconds:stage:currentWinStreak:)` formula — separate from
`TimeTrialRules.score(remainingSeconds:gridSize:)`, which stays untouched since it's
already recorded in players' single-puzzle personal bests. `GameSession` tracks
`currentLadderStage`, `ladderCumulativeScore`, `ladderWinStreak`, and the run-ending
`isLadderRunFailed`/`isLadderRunComplete` flags; a stage clear explicitly skips
`recordCompletion`/`recordTimeTrialScore` (a ladder run spans every grid size in the table,
so crediting one stage's clear to that size's single-puzzle personal best would silently
pollute it) and instead feeds two new flat, non-`StatsKey`-scoped `StatsStore` fields —
`bestLadderScore`/`bestLadderStageReached` — since a ladder run isn't scoped to one grid
size the way every other stat in this app is. `CompletionBannerView`/`TimeTrialFailView`
absorb the ladder's "Stage N Cleared!"/"Gauntlet Complete!"/"Ladder Run Over" states as
additive parameters and computed properties, the same pattern used when Time Trial's own
score/fail states were added, rather than forking new views.

**Limited Moves mode** (shipped June 2026): a flat per-grid-size move budget — every move
costs exactly 1 toward the budget, regardless of whether it locks a tile correctly (unlike
Time Trial, where correctness changes the time delta). `Models/LimitedMovesRules.swift`
holds the pure, table-driven budget (3×3 → 12 moves, scaling up to 115 for 8×8 and beyond),
unit-testable with no `GameSession` dependency. `GameSession` exposes
`isLimitedMovesMode`/`isLimitedMovesFailed`/`movesBudgetForCurrentSize`/
`limitedMovesRemaining`, and `registerMove()` calls `applyLimitedMovesBudgetCheck()` (the
same dispatch point as Time Trial's `applyTimeTrialMoveOutcome()`) which fails the puzzle
once `currentMoveCount` reaches the budget without solving — checked *after* the solved
branch, so a move that both exhausts the budget and solves the puzzle counts as a win, not
a simultaneous fail. Unlike Time Trial, Limited Moves works with both `ClassicEngine` and
`SlideEngine` (it has no dependency on `isLocked`/correctness, just a raw move count) and
adds no new scoring system or `StatsStore` field — completions feed the same
`personalBestMoves`/`personalBestTime` path as Classic/Slide, and like Zen, streak
tracking is skipped entirely. `PuzzleCompletionViewModel` gained a `showLimitedMovesFail`
flag (driving `LimitedMovesFailView`, an "Out of Moves" overlay mutually exclusive with the
regular completion banner, the same pattern as `TimeTrialFailView`), and
`LimitedMovesCounterView` is its HUD pill ("N left", color-coded by fraction of budget
remaining).

**§6 resolution**: with both Time Trial and Limited Moves now shipped, the question of
whether mode-specific behavior deserves a generic `GameModeRules` abstraction was
revisited a second time — and conditionals still won, though more narrowly than before.
Time Trial and Limited Moves *do* share a real axis this time ("a budget + a fail
condition, checked after the solved branch, with a dedicated fail overlay"), confirming the
prediction made the last time this section was written. But the budgets themselves differ
in kind enough that a shared struct would mostly hold optional/unused fields either way:
Time Trial's budget is wall-clock time that *mutates per move* (a correct move adds time, a
wrong one subtracts it) and feeds a combo-scored personal best; Limited Moves' budget is a
flat move count that only ever decrements by exactly 1 and feeds no score at all, just the
existing moves/time records. Pulling the "budget + fail" shape into `GameModeRules` now
would save two small `if`/`else if` branches in `registerMove()` at the cost of a generic
type whose fields don't mean the same thing across its two conformers — not yet a clear
win. Zen still doesn't fit this axis at all; it disables tracking rather than budgeting
anything. Revisit again if a third budget-based mode arrives (Fog/Reveal and Chaos, per
`ROADMAP.md` §1, are visual-twist modes, not budget modes, so neither is that third data
point) — three real conformers sharing the same "budget + fail" axis would make the
abstraction's payoff much clearer than two.

**Image pipeline**: `ImageSource` protocol → `RemoteImageSource` (picsum.photos) /
`PhotoLibraryImageSource` / `LocalImageSource` (bundled fallback) → `ImageService` (primary
+ fallback on `URLError`) → `ImageSlicer` (center-crop + slice into per-tile `CGImage`s,
stored in `GameSession.tileImages`).

**Persistence**: still `UserDefaults` only, but behind `PersistenceStore` now (see above),
and each store owns and persists only its own keys. `StatsStore`'s per-`(gridSize,
gameMode)` stats use string-keyed lookups built from a `3...8 × GameMode.allCases` loop. No
SwiftData yet (flagged in `ROADMAP.md` §4 as the natural next step once stats history/charts
are wanted).

**Testing**: `NineTilesPuzzleTests` is a real Unit Testing Bundle target (added manually in
Xcode in June 2026 — it existed as a folder of source files for a while before that without
ever actually being wired up or compiled). 117 tests currently pass, covering: both engines
and `SlideSolver`, `ImageService`/`ImageSlicer` (including a fallback test for non-network
decode failures), all four stores (`StatsStore` and `AchievementsStore` via
`InMemoryPersistenceStore`), `PuzzleCompletionViewModel`, `TimeTrialRules`,
`GauntletLadderRules`, `LimitedMovesRules`, and `GameSessionTimeTrialTests`/
`GameSessionGauntletLadderTests`/`GameSessionLimitedMovesTests` suites exercising the full
Time Trial, Gauntlet Ladder, and Limited Moves integrations (countdown lifecycle, combo
bonus/penalty, fail state, score recording, stage progression, win-streak scoring, run
completion/failure, a regression test proving a ladder stage clear never pollutes the
per-size single-puzzle Time Trial personal bests, every-move-costs-1 budget accounting, and
a budget-exhausted-but-also-solved win/fail tie-break) end to end against a real
`GameSession` — using `.numbers` media mode (no network/image work) and hand-built tile
layouts to engineer specific moves deterministically, since these tests
never `await` a real sleep and so the countdown's background tick task never gets scheduled
mid-test. One thing this pattern doesn't cover: a true persistence round-trip (write, then
reconstruct a second `GameSession` and read back) isn't practical for a session using
`.numbers` media outside Slide mode, since `restoreFromUserDefaults()`'s existing "Numbers
is Slide-only" guard resets `mediaSourceType` away from `.numbers` on restore — correct
production behavior, but it trips the tile-restore guard chain for this test shape, so the
Gauntlet Ladder's persistence test instead asserts directly against the in-memory
`PersistenceStore` fake. Getting the target wired up surfaced three real,
previously-undetected bugs that had been sitting in untested code paths — two missing
imports and one test with a geometrically-invalid fixture (asserted a slide between two
non-adjacent grid cells) — all fixed once the target could finally compile and run them.
