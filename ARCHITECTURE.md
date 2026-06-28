# NineTilesPuzzle — Architecture Overview

Snapshot of the current codebase structure, as of 2026-06-27 (updated for Wall of Fame + Stats→Settings). This is a descriptive
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
├── NineTilesPuzzleApp.swift        — @main, constructs StatsStore, SettingsStore,
│                                    AchievementsStore, DailyChallengeStore, WallOfFameStore,
│                                    MotionManager, SoundService, GameCenterService;
│                                    injects all into the environment; kicks off GC auth via .task
├── Models/
│   ├── GameSession.swift           — the game currently configured/in progress (see below)
│   ├── StatsStore.swift            — personal bests, games played, streaks (keyed by StatsKey)
│   ├── DailyChallengeStore.swift   — daily-challenge-specific stats: calendar streak,
│   │                                  best calendar streak, last completed date, daily
│   │                                  best moves/time. Fully independent of StatsStore.
│   ├── DailyChallengeSeeder.swift  — pure enum: date→UInt64 seed, seeded picsum URL
│   │                                  (/seed/ntp-YYYY-MM-DD/1024/1024), deterministic
│   │                                  derangement shuffle via xorshift64 PRNG (SeededGenerator)
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
│   ├── ChaosTransform.swift        — pure whole-image orientation/tone/posterize/pixelate
│   │                                  transform for Chaos Mode (see below)
│   ├── TileModel.swift             — @Observable tile: id, currentIndex, isLocked
│   ├── Achievement.swift           — Codable definition: id, title, systemImage, category,
│   │                                  metric, target, comparison, isUnlocked, unlockedDate
│   ├── AchievementCategory.swift   — 6-case enum (milestones/difficulty/efficiency/
│   │                                  streaks/explorer/special); drives AchievementsView sections
│   ├── AchievementMetric.swift     — what a target is measured against; encodes as a dotted
│   │                                  string (e.g. "personalBestMoves.3.swap") for hand-editable
│   │                                  JSON; value(in:justSolved:now:) reads StatsStore
│   ├── AchievementComparison.swift — greaterThanOrEqual | lessThanOrEqual
│   ├── WallOfFameSlot.swift        — 15-case enum: bestMoves(3…8), bestTime(3…8),
│   │                                  dailyBestMoves, dailyBestTime, calendarStreak;
│   │                                  exposes fileName, displayTitle, seedValue
│   ├── WallOfFameStore.swift       — @Observable, @MainActor; persists card PNGs to
│   │                                  Documents/wall_of_fame/<slot>.png via ImageIO (no UIKit);
│   │                                  caches CGImages in memory; exposes cardImage(for:),
│   │                                  save(_:for:) (disk write off main actor), fileURL(for:)
│   ├── ZenSparkle.swift            — decorative particle model for Zen mode's solve animation
│   ├── Bundle-Decodable-Ext.swift
│   ├── TimeInterval-Formatting-Ext.swift
│   └── Image/
│       ├── MediaSourceType.swift   — enum: random/local/mixed/numbers
│       ├── RemoteImageSource.swift — also declares the `ImageSource` protocol
│       ├── LocalImageSource.swift  — bundled fallback image
│       ├── PhotoLibraryImageSource.swift
│       ├── DailyImageSource.swift  — fetches today's seeded picsum image via system
│       │                              URL cache (same date → same image, at most one
│       │                              network call per day)
│       └── ImageSourceError.swift
├── Services/
│   ├── GameEngine.swift            — protocol: shuffle() + shared isSolved()
│   ├── SwapEngine.swift            — swap-any-two-tiles rules (was ClassicEngine)
│   ├── SlideEngine.swift           — 15-puzzle slide rules + solvability parity check
│   ├── SlideSolver.swift           — BFS solver, debug-only "Solve" button
│   ├── ImageService.swift          — primary/fallback source orchestration
│   ├── ImageSlicer.swift           — center-crop + slice CGImage into tile images
│   ├── MotionManager.swift         — @Observable, @MainActor; wraps CMMotionManager at 60 Hz
│   │                                  (pull model: no callback queue, just polls the latest sample).
│   │                                  Derives pitch/roll on-demand from `CMDeviceMotion.gravity`
│   │                                  (absolute, accelerometer-fused, drift-free "down") rather than
│   │                                  calibrating to a reference attitude. Maps to −1…1 normalized,
│   │                                  clamped at ±0.14 rad (≈ 8°); includes a near-flat guard
│   │                                  (minPlanarGravity = 0.05) so settled cards don't jitter.
│   │                                  Exposes computed properties `pitch`/`roll` and static functions
│   │                                  `normalizedPitch(...)` / `normalizedRoll(...)` for unit testing.
│   │                                  startUpdates()/stopUpdates()
│   ├── SoundService.swift          — @Observable, AVAudioPlayer-backed SFX
│   ├── AchievementService.swift    — bundled JSON + remote fetch + on-disk cache
│   └── GameCenterService.swift     — @Observable, handles GKLocalPlayer authentication;
│                                     exposes isAuthenticated + showDashboard() which
│                                     triggers the native Game Center UI via
│                                     GKAccessPoint.trigger(handler:) (the iOS 26 replacement
│                                     for the deprecated GKGameCenterViewController)
├── Views/
│   ├── MenuView.swift               — root NavigationStack, routes via GameRoute enum;
│   │                                  Stats button removed — Stats now lives in Settings
│   ├── StatsView.swift              — push-navigation destination (no NavigationStack of its
│   │                                  own); reached via NavigationLink in SettingsView;
│   │                                  shows streaks, personal bests, games played
│   ├── AchievementsView.swift       — sheet: achievement list
│   ├── GameMode/GameModeView.swift  — mode picker only (media source moved to MenuView)
│   ├── Settings/                    — SettingsView, GridSizePickerView, PreviewTimePickerView,
│   │                                  MediaSourcePickerView (moved here from GameModeView)
│   ├── Streak/                      — StreakCounterView, StreakStatsView, StreakCountdownPickerView,
│   │                                  MenuStatsCardView (mode-aware menu card: 3-stat for
│   │                                  Swap/Slide/Haze/Chaos, 2-stat for Time Trial / Limited
│   │                                  Moves / Gauntlet, hidden for Zen)
│   ├── Puzzle/
│   │   ├── PuzzleView.swift                 — game screen orchestrator (mostly rendering now;
│   │   │                                      sequencing delegated to the view model below)
│   │   ├── PuzzleCompletionViewModel.swift  — completion banner, new-record badge timing,
│   │   │                                      drag-to-dismiss, Zen's breathe/sparkle sequence
│   │   ├── PuzzleGridView.swift     — tile layout, drag handling, slide/swap dispatch
│   │   ├── TileView.swift           — single draggable tile; owns the three Haze visual
│   │   │                              states (fogged / frosted-glass-while-dragging / revealed)
│   │   ├── FogTileOverlay.swift     — Canvas+TimelineView animated star-field particle system,
│   │   │                              per-tile seed so each tile's field is unique
│   │   ├── ImagePreviewView.swift   — pre-shuffle reveal; takes `isFogMode` param — fog
│   │   │                              overlay, shake badge, and shake gesture are gated so
│   │   │                              they only activate in Haze mode; badge sits in a top
│   │   │                              overlay (not the layout flow) so image position matches
│   │   │                              the in-game grid across all modes
│   │   ├── PuzzleStatusBarView.swift, MoveCounterView.swift, TimeCounterView.swift
│   │   ├── TimeTrialTimerView.swift, TimeTrialScoreView.swift — Time Trial's HUD
│   │   ├── TimeTrialDeltaIndicatorView.swift — transient "+1s"/"-2s" combo indicator
│   │   ├── GauntletStageIndicatorView.swift — "Stage N of 10" HUD pill
│   │   ├── LimitedMovesCounterView.swift — Limited Moves' "N left" HUD pill, color-coded
│   │   │                                   by fraction of budget remaining
│   │   └── PuzzleErrorView.swift
│   ├── Daily/
│   │   └── DailyChallengeCardView.swift — menu card: today's date, calendar streak,
│   │                                       "Play" button (or "Done ✓" once completed)
│   ├── WallOfFame/
│   │   ├── WallOfFameView.swift     — root ZStack: ScrollView(cork board) + backdrop +
│   │   │                              zoom overlay as three siblings so each can carry its
│   │   │                              own SwiftUI transition independently; sections: Best
│   │   │                              Moves, Fastest Solve, Daily Challenge, Streaks; owns
│   │   │                              WallOfFameSwingEngine and mounts WallOfFameSwingDriver
│   │   ├── WallOfFamePinnedCard.swift — 160×192 pt polaroid; reads its own CardSwing angle
│   │   │                              and applies it to rotationEffect; registers/unregisters
│   │   │                              with the shared engine on appear/disappear
│   │   ├── CardSwing.swift          — @Observable per-card pendulum state: observed `angle`,
│   │   │                              @ObservationIgnored `velocity`; stepped by the engine
│   │   ├── WallOfFameSwingEngine.swift — @Observable shared physics engine; steps all
│   │   │                              registered CardSwing instances each frame, only writing
│   │   │                              `angle` when motion exceeds rest threshold; 1/60 Hz
│   │   ├── WallOfFameSwingDriver.swift — invisible view with the single `TimelineView`
│   │   │                              (.animation 60 fps); ticks engine.step(roll:) from
│   │   │                              motionManager.roll; replaces 15 per-card timelines
│   │   └── WallOfFameEmptySlot.swift — dashed rounded-rect placeholder for unfilled slots
│   └── Helpers/                     — grab-bag of small reusable views (toast, banners,
│                                       loading/splash, brand mark, badges, zen sparkle,
│                                       AchievementRowView (icon + title/description + inline
│                                       progress bar for count-based achievements, best-moves
│                                       hint for efficiency achievements, unlock date for
│                                       unlocked ones), Time Trial's "Out of Time" overlay,
│                                       Limited Moves' "Out of Moves" overlay, ShakeDetector
│                                       UIKit bridge, LoudBounceModifier scale-pop modifier)
├── Resources/                       — achievements.json, sounds, asset catalog, app icon
NineTilesPuzzleTests/                 — real, wired-up Unit Testing Bundle target (see below)
```

## Core data flow

```
NineTilesPuzzleApp.init()
   constructs, in dependency order:
     StatsStore()  SettingsStore()  AchievementsStore()  ──▶  GameSession(stats:, achievements:, settings:)
     WallOfFameStore()   MotionManager()   SoundService()   GameCenterService()   DailyChallengeStore()
   (each store defaults its `defaults:` param to UserDefaults.standard via PersistenceStore)
   injects all into the environment (app-wide singletons)
        │
        ▼
MenuView ── NavigationStack(GameRoute) ──▶ PuzzleView / WallOfFameView / GameModeView / ...
   ├── SettingsView (sheet, owns a NavigationStack)
   │       └── NavigationLink ──▶ StatsView (plain List, no own NavigationStack)
   └── (each view reads only the store(s) it actually needs from the environment)
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
  The check is fully data-driven: for each `Achievement` in the list (loaded from
  `achievements.json` via `AchievementService`), it calls `metric.value(in: stats)` and
  compares against `target` using `comparison` — no hardcoded per-id `switch`. The
  Completionist achievement is the one exception: it's skipped in the generic loop and handled
  by `updateCompletionistAchievement`, since "all others unlocked" depends on the list itself.
  `AchievementsView` groups rows into sections by `AchievementCategory`; `AchievementRowView`
  reads `StatsStore` from the environment to render inline progress for count-based
  achievements (≥, target > 1) and a best-moves hint for efficiency achievements (≤).

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

**Game modes today**: `GameMode` is 7 cases; all 7 are now live (`.classic`, `.slide`,
`.zen`, `.timeTrial`, `.limitedMoves`, `.chaos`, `.fog`). The `.fog` case displays as
**Haze** (renamed June 2026 — raw value kept as `"fog"` to preserve persisted user
preferences). Mode-specific behavior is still expressed as scattered conditionals
(`isZenMode`, `isTimeTrialMode`, `isLimitedMovesMode`, `isFogMode`,
`selectedGameMode == .slide`, `settingsStore.debugOverlayEnabled`) inside `GameSession` and
`PuzzleView`/`PuzzleGridView` — see the §6 resolution below for why this
stayed conditionals-based even with Time Trial and Limited Moves as two structurally similar
real modes.

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

**Gauntlet Ladder** (Time Trial sub-mode, shipped June 2026; time limits nerfed June 2026
after playtesting — roughly +20–35% per stage, larger grids scaled more generously):
a toggleable 10-stage progression inside Time Trial — `GameSession.isLadderMode`, surfaced
as a `Toggle` in `GameModeView` only when `.timeTrial` is selected, not a separate `GameMode`
case (it's the
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

**Chaos Mode** (shipped June 2026): a whole-image visual twist, not a per-tile one. A random
`Models/ChaosTransform.swift` value — one `Orientation` pick (mirror/flip/rotate90/180/270),
one `Tone` pick (desaturate/invert/hue-shift/sepia), plus independent `posterize` and
`pixelate` coin flips (pixelate weighted lower at 25%, since its block size reads as a much
stronger effect than the others) — is baked into the source `CGImage` via Core Image filters
once, in `GameSession.startNewGame()`/`startNewRandomGame()`, *before* `ImageSlicer` ever
slices it. Baking the transform into the image rather than tracking it as separate state
means every tile inherits the same look (the solved puzzle still reads as one coherent
photo, not a mosaic of independently-warped pieces) and the transformed image rides along
for free through the existing `sourceImage`/restore-from-`UserDefaults` path, with no new
persistence key and no risk of re-rolling a different transform on restore than the one the
tiles were actually shuffled against. `GameSession` gained a dedicated `previewImage`
field — always the untouched, untransformed center-crop — because the existing
`croppedSourceImage` field became "post-transform" the moment Chaos started writing to it,
and `ImagePreviewView`'s pre-shuffle "memorize the image" step needs to show the real photo,
not the mirrored/inverted/pixelated one the tiles are about to show. Pixelate's block grid is
centered on the image, so `ChaosTransform.zoomedToHideEdgeBand` crops the partial-block
margin at each edge and zooms the clean interior back to fill the frame — otherwise that
ring lined up exactly with the puzzle's border tiles and was a free tell for which pieces sit
on the edge. Chaos has no new `GameEngine`, no fail state, and no stats/streak exemption: it
runs on `ClassicEngine` like Swap and feeds the same completion/streak/personal-best path,
since the transform is purely visual noise on top of an otherwise-ordinary Swap game.

**Haze** (shipped June 2026, originally "Fog Mode" — display name updated June 2026, raw
value `"fog"` preserved): a tile-level reveal mode — the second visual-twist mode after
Chaos, implemented at the tile rendering layer rather than as a whole-image bake. Three
visual states per tile, driven by `TileModel` fields and `TileView`'s local `isDragging`:

- **Fogged** (`isFogMode && !tile.isLocked && !isDragging`): `TileContentView` blurred at
  18pt + `Color.black.opacity(0.45)` tint + `FogTileOverlay` sparkles.
- **Frosted glass** (`isFogMode && !tile.isLocked && isDragging`): blur drops to 3pt, tint
  and sparkles hidden — the image is barely readable while a tile is in motion.
- **Revealed** (`tile.isLocked`): no blur, no overlay; transitions from fog over 1.2s
  easeInOut.

`FogTileOverlay` (`Views/Puzzle/`) is a `Canvas`+`TimelineView` particle system: each frame
draws N twinkling ellipses whose brightness oscillates via `sin(time * freq + phase)`. A
`seed: Float` parameter (passed as `Float(tile.id)`) offsets the particle index sequence by
`seed × 1000`, making each tile's star field visually distinct without any per-instance
state. Particle count scales with tile area (`max(640, Int(area / 6.875))`); `time` is
sourced from `timeline.date.timeIntervalSince1970` (large absolute value — acceptable since
`sin()` is periodic and only brightness oscillates, not position).

`ShakeDetector` (`Views/Helpers/`) is a lightweight `UIViewControllerRepresentable` that
overrides `motionBegan(_:with:)` and fires a closure on `.motionShake` — the UIKit bridge
needed because SwiftUI has no shake API. Active only during the preview phase.

`ImagePreviewView` takes an `isFogMode: Bool` parameter; the fog overlay, "Shake to reveal"
badge, and shake gesture are all gated on it so other modes get a plain "Memorize the image"
preview with no fog or shake. The badge lives in a top `.overlay` (not the VStack layout
flow), so the preview image sits at the same vertical position as the in-game grid regardless
of whether the badge is visible. The countdown bar is driven by a `duration: Double`
parameter (fed from `GameSession.currentPreviewDuration` = `settingsStore.previewDuration`)
so it always matches the actual preview length.

`LoudBounceModifier` (`Views/Helpers/`) is a repeating `keyframeAnimator` modifier: a
scale spring pop (1.0 → 1.25, `Spring(response: 0.25, dampingRatio: 0.48)` for natural
overshoot, then back via `Spring(response: 0.42, dampingRatio: 0.66)`), a `brightness`
flash at pop peak, and a horizontal offsetX rattle — iMessage Loud+Shake style. Factored
into its own file and exposed as `.loudBounce()` so it's reusable anywhere.

Haze has no new `GameEngine`, no new fail state, and no stats/streak exemption — it runs on
`ClassicEngine` (SwapEngine) and feeds the same completion/streak/personal-best path as
Swap. `GameSession.isFogMode` is the single gate (`selectedGameMode == .fog`);
`currentPreviewDuration` is the only new computed property added to `GameSession`.

**Daily Challenge** (shipped June 2026): one puzzle per day, identical for every player.
Implemented as a transient `GameSession.isDailyGameActive` flag rather than a new `GameMode`
case — this keeps the user's regular mode preference untouched. `DailyChallengeSeeder`
derives a `UInt64` seed from calendar date components, generates a deterministic picsum seed
URL (`/seed/ntp-YYYY-MM-DD/1024/1024`), and produces the same Fisher-Yates derangement via
a xorshift64 PRNG (`SeededGenerator`) — identical seed + count → identical tile arrangement
for every player. `DailyImageSource` fetches via the system URL cache (the regular
`RemoteImageSource` bypasses it), so the image is downloaded at most once per calendar day.
`DailyChallengeStore` is a fifth, fully independent `@Observable` store: calendar streak,
best calendar streak, last completed date, daily best moves/time — none of this touches
`StatsStore`. `enterDailyMode()` sets the flag; `startNewGame()` checks it to override grid
size to 4×4, use `DailyImageSource`, and apply a seeded shuffle instead of
`activeEngine.shuffle()`. `registerMove()` checks it to skip the move-streak countdown and
to route solve completion to `DailyChallengeStore.recordCompletion()` (which also feeds
`statsStore.recordGameCompletedToday()` and `recordZeroWasteSolve()` for achievement
purposes). `leaveGame()` resets the flag. The card `DailyChallengeCardView` on the menu
reads `DailyChallengeStore` directly from the environment and shows a "Done ✓" indicator
once `isDailyCompletedToday`; the flag is not persisted (transient) so a force-quit mid-game
just restarts the same daily puzzle on next launch.

**Wall of Fame** (shipped June 2026): a cork-board view where every personal best is
automatically captured and pinned as a polaroid card. `PuzzleView` renders `ShareCardView`
via `ImageRenderer` at 3× scale at the moment a record is set, converts the result to a
`CGImage`, and calls `WallOfFameStore.save(_:for:)`. `WallOfFameStore` writes a PNG to
`Documents/wall_of_fame/<slot>.png` using `CGImageDestinationCreateWithData` / ImageIO
(no UIKit, compatible with `ShareLink`'s `URL`-based `Transferable` requirement); the
in-memory `[WallOfFameSlot: CGImage]` cache avoids repeated disk reads within a session.

`WallOfFameView` is a `ZStack` containing three sibling layers:
1. `ScrollView` — the cork board with four `LazyVGrid` sections.
2. `Color.black.opacity(0.78)` backdrop — conditional on `zoomedCardImage != nil`,
   transition `.opacity`.
3. `ZoomedCardOverlay` (card + transparent dismiss button) — conditional on `let image =
   zoomedCardImage`, transition `.scale(0.82).combined(with: .opacity)`.

Separating the backdrop and card into siblings (rather than one `ZoomedCardOverlay` containing
both) is what lets each carry its own `SwiftUI.transition` — backdrop fades while the card
scales, both driven by a shared `.animation(..., value: zoomedCardImage == nil)` on the
`ZStack`. The dismiss button in `ZoomedCardOverlay` is a full-screen `Color.clear.ignoresSafeArea()
.contentShape(.rect)` — it expands to fill all available space so tapping anywhere
(backdrop or card) dismisses without a button-press color flash. The card image is layered
on top via `.overlay` with `.allowsHitTesting(false)` so taps pass through to the button;
the dark backdrop sibling also has `.allowsHitTesting(false)` so neither intercepts.

**Pendulum physics** (`WallOfFameSwingEngine`): a single `WallOfFameSwingDriver` mounts one
shared `TimelineView(.animation(minimumInterval: 1/60))` in the `WallOfFameView`. Each frame
it calls `engine.step(roll:)`, which iterates all registered `CardSwing` instances and applies
the spring-damper loop:
```
let springForce  = (targetAngle − velocity) × stiffness   // stiffness = 0.025
let dampingForce = −velocity × damping                     // damping   = 0.11
newVelocity      = velocity + springForce + dampingForce
newAngle         = angle + newVelocity
```
`targetAngle = −motionManager.roll × 6.0` (negated: tilt right → cards swing left). The
engine only writes a card's observed `angle` if it exceeds the rest threshold (motion > 0.01°
and distance-to-target > 0.01°), so settled cards stop re-rendering until the next tilt.
Cards register with the engine on `.onAppear` and unregister on `.onDisappear`, so only
visible cards incur physics cost. Each card has a seeded `baseAngle` (±6°) additive with
`swingAngle`, so cards rest at unique angles and the whole board sways together.

**`MotionManager`** (`Services/MotionManager.swift`): `@MainActor @Observable`, starts
`CMMotionManager.startDeviceMotionUpdates` at 60 Hz (pull model: no callback queue). Derives
`pitch`/`roll` on-demand as computed properties from `CMDeviceMotion.gravity`, the
accelerometer-fused, drift-free measurement of real-world "down" — not calibrated to a
reference attitude. Maps gravity angles to −1…1 normalized, clamped at ±0.14 rad (≈ 8°).
Includes a near-flat guard (`minPlanarGravity = 0.05`) so that when the device lies flat and
screen-plane gravity vanishes, cards rest level instead of slamming to one side (a real-sensor
edge case where `atan2(0, -0)` returns π). `stopUpdates()` zeroes the motion sample, so
computed properties return 0, and the cards snap to their base angles when the view
disappears. Static functions `normalizedRoll(gravityX:gravityY:)` and
`normalizedPitch(gravityX:gravityY:gravityZ:)` are `CoreMotion`-free and unit-testable.

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
anything. Revisit again if a third budget-based mode arrives. Both remaining planned modes — Fog/Reveal
and Chaos — have now shipped as visual-twist modes, not budget modes, so neither is that
third data point. All 7 `GameMode` cases are live; no new mode is currently planned that
would change this calculus.

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
ever actually being wired up or compiled). 123 tests currently pass, covering: both engines
and `SlideSolver`, `ImageService`/`ImageSlicer` (including a fallback test for non-network
decode failures), all four stores (`StatsStore` and `AchievementsStore` via
`InMemoryPersistenceStore`), `PuzzleCompletionViewModel`, `TimeTrialRules`,
`GauntletLadderRules`, `LimitedMovesRules`, `ChaosTransformTests` (dimension-preservation
across every orientation/tone, posterize/pixelate individually and stacked, and a
random-combination fuzz pass asserting `ChaosTransform.random()` never produces a crashing
combination), and `GameSessionTimeTrialTests`/
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
