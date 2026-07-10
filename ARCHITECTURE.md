# NineTilesPuzzle — Architecture Overview

Snapshot of the current codebase structure, as of 2026-07-05 (updated for Wall of Fame + Stats→Settings, a July 2026 performance pass, the Live Activity, and home-screen widgets + deep links). This is a descriptive
document — see this file's own §6 resolution below (and `ROADMAP.md` §6, kept in sync with
it) for how the "does mode-specific behavior need a shared abstraction" question was
revisited once Time Trial and Limited Moves both existed, and what would justify
revisiting it again.

## Tech stack

- SwiftUI, iOS only, dark-mode-locked (`.preferredColorScheme(.dark)`)
- `@Observable` classes for shared state (no `ObservableObject`/Combine)
- Swift Concurrency throughout (`async/await`, structured `Task`s) — no GCD
- Persistence: `UserDefaults` only, no SwiftData/CloudKit yet — but abstracted behind a
  `PersistenceStore` protocol (see below), so that's a non-disruptive future swap. The one
  addition: widget-visible state is mirrored into the App Group suite
  (`group.cilia.filippo.NineTilesPuzzle`) as a single JSON blob (see §Home-screen widgets)
- A widget extension target (`NineTilesPuzzleWidgetsExtension`) hosting the Live Activity
  and three home-screen widgets; a handful of files are compiled into both targets
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
│   │                                  countdown durations, Quick Snap timer, haptics, debug overlay
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
│   ├── WallOfFameSlot.swift        — 25-case enum: bestMoves(3…8), bestTime(3…8),
│   │                                  dailyBestMoves, dailyBestTime, calendarStreak,
│   │                                  ladderStage(1…10); exposes fileName, displayTitle, seedValue
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
├── Shared/                          — compiled into BOTH the app and the widget extension
│   │                                  (target sharing = membershipExceptions in project.pbxproj;
│   │                                  everything here is explicitly `nonisolated` because the
│   │                                  app target defaults to MainActor isolation)
│   ├── PuzzleActivityAttributes.swift — Live Activity ActivityAttributes + ContentState
│   ├── LiveActivityStore.swift     — App Group ID + shared-container URL helpers for
│   │                                  board snapshot PNGs
│   ├── WidgetDataStore.swift       — WidgetSnapshot (Codable schema: daily/modeStats/resume
│   │                                  sections, all optional-tolerant), load/save through the
│   │                                  App Group defaults, WidgetKind reload identifiers
│   └── DeepLink.swift              — ninetilespuzzle:// routes (daily/resume/mode) with
│                                      URL round-trip + validation
├── Services/
│   ├── GameEngine.swift            — protocol: shuffle() + shared isSolved()
│   ├── LiveActivityController.swift — owns the "puzzle in progress" Live Activity lifecycle:
│   │                                  start/refresh/end, board PNG writes (board-<UUID>.png),
│   │                                  1h staleDate, stray-activity reaping
│   ├── WidgetDataController.swift  — owns every WidgetSnapshot write + scoped
│   │                                  WidgetCenter.reloadTimelines(ofKind:) call; per-section
│   │                                  Hashable diffing; Resume board PNG pipeline
│   │                                  (widget-board-<UUID>.png); no-ops without the App Group
│   ├── SwapEngine.swift            — swap-any-two-tiles rules (was ClassicEngine)
│   ├── SlideEngine.swift           — 15-puzzle slide rules + solvability parity check
│   ├── SlideSolver.swift           — BFS solver, debug-only "Solve" button
│   ├── ImageService.swift          — primary/fallback source orchestration
│   ├── ImageSlicer.swift           — center-crop + slice CGImage into tile images
│   ├── QuickSnapCameraSession.swift — @MainActor @Observable AVCaptureSession wrapper for the
│   │                                  Quick Snap camera; configure()/capture()/stop() + the
│   │                                  isCameraAvailable gate used to hide the mode/setting
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
│   ├── GameRoute.swift               — shared NavigationStack route enum + beginGame(session:path:)
│   │                                   helper (reset board, push .game)
│   ├── Menu/
│   │   ├── MenuView.swift            — root NavigationStack shell; routes via GameRoute enum;
│   │   │                              Stats button removed — Stats now lives in Settings
│   │   ├── MenuOptionsCardView.swift — Game Mode/Media/Grid Size/Achievements/Wall of Fame/
│   │   │                              Challenge Nearby Friends row card
│   │   ├── MenuRouteDestinationView.swift — resolves a GameRoute to its destination screen
│   │   └── ChallengeFileOpeningModifier.swift — receiving a .ntpchallenge file (onOpenURL,
│   │                                  invite/result/failure alerts); .handlingOpenedChallengeFiles(_:)
│   ├── StatsView.swift              — push-navigation destination (no NavigationStack of its
│   │                                  own); reached via NavigationLink in SettingsView;
│   │                                  shows streaks, personal bests, games played
│   ├── AchievementsView.swift       — sheet: achievement list
│   ├── GameMode/GameModeView.swift  — mode picker only (media source moved to MenuView)
│   ├── Settings/                    — SettingsView, GridSizePickerView, PreviewTimePickerView,
│   │                                  QuickSnapDurationPickerView, MediaSourcePickerView
│   │                                  (moved here from GameModeView)
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
│   │   │                              states (fogged / frosted-glass-while-dragging / revealed).
│   │   │                              Renders only the fog blur + dark scrim; the animated
│   │   │                              sparkles are drawn board-wide by PuzzleFogLayer
│   │   ├── FogField.swift           — pure particle-drawing routine (twinkling ellipse field for
│   │   │                              a given rect/seed/time); shared by the two fog views below
│   │   ├── PuzzleFogLayer.swift     — single board-level Canvas+TimelineView (30 fps) that draws
│   │   │                              the sparkle field over every unrevealed tile at once,
│   │   │                              replacing the previous per-tile FogTileOverlay timelines
│   │   ├── FogTileOverlay.swift     — standalone star-field overlay (via FogField); now used
│   │   │                              only by the Fog Mode preview card in ImagePreviewView
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
│   │   ├── QuickSnapCameraView.swift — full-screen Quick Snap capture: live feed + countdown
│   │   │                              ring; whole viewfinder is a tap-to-snap shutter, per-second
│   │   │                              + capture haptics; auto-captures at zero. Presented from
│   │   │                              MenuView (first shot) and PuzzleView ("Play Again" re-capture)
│   │   ├── CameraPreviewView.swift  — UIViewRepresentable bridging the AVCaptureVideoPreviewLayer
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
NineTilesPuzzleWidgets/               — widget extension target (NineTilesPuzzleWidgetsExtension)
├── NineTilesPuzzleWidgetsBundle.swift — @main WidgetBundle: DailyChallengeWidget,
│                                       StreaksRecordsWidget, ResumeGameWidget, PuzzleLiveActivity
├── DailyChallenge/                  — widget + systemSmall/Medium views (home screen only —
│                                       no Lock Screen accessory families)
├── StreaksRecords/                  — AppIntent configuration (WidgetGameMode/WidgetGridSize
│                                       AppEnums, StatsConfigurationIntent) + widget + views
├── ResumeGame/                      — widget + views incl. ResumeBoardThumbnail (accented-mode
│                                       desaturation wrapper around the board image)
└── Views/                           — Live Activity presentation (PuzzleLiveActivity, Lock Screen
                                        card, Dynamic Island) + shared pieces reused by the
                                        widgets: StatBadge, ProgressRing, ProgressBar,
                                        ModeGlyphBadge, BoardThumbnail, BrandPuzzleMark
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
  `AchievementsView` groups rows into sections by `AchievementCategory` — reading the
  precomputed `AchievementsStore.achievementsByCategory` (one O(n) grouping) and
  `unlockedCount` rather than re-filtering the array per category on every render, a July 2026
  perf tidy-up. `AchievementRowView` reads `StatsStore` from the environment to render inline
  progress for count-based achievements (≥, target > 1) and a best-moves hint for efficiency
  achievements (≤).

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

`StatsStore.bestLadderStageScores: [Int: Int]` (added July 2026) tracks the best score ever
scored while clearing each individual stage, keyed by stage number — distinct from
`bestLadderStageReached`, which only records the furthest stage any run has ever reached.
`GameSession.isNewLadderStageBestRecord` fires whenever a stage clear's score beats that
stage's own entry, alongside `lastLadderStageScore`; `PuzzleView` captures a Wall of Fame
`.ladderStage(n)` card at that moment (`ShareCardView`'s optional `ladderStage`/
`ladderStageScore` parameters swap in a "Gauntlet · Stage N" chip and a score badge in place
of the daily-streak ones), backing the Wall of Fame's "Gauntlet Ladder" section — one card
per stage, showing the player's best-ever clear of it. Since stages are sequential,
`WallOfFameEmptySlot` (also July 2026) distinguishes an unreached ladder stage — dimmer
border, a small lock glyph, "Locked" — from every other empty slot's plain "not yet earned"
placeholder, using `stage > StatsStore.bestLadderStageReached + 1` as the locked test (`+ 1`
so the very next stage in reach still reads as ordinarily unearned, not locked).

`WallOfFameStore.heroSlot(forGridSize:)` (added July 2026) backs the "Difficulty Highlights"
section: one card per grid size (3…8), rather than duplicating the Best Moves/Fastest Solve
split. It picks whichever of `.bestMoves(size)`/`.bestTime(size)` was captured more
recently — an in-memory `lastModified: [WallOfFameSlot: Date]` set optimistically in
`save()` (so a fresh capture immediately outranks the other before the async PNG write
lands), falling back to the on-disk PNG's modification date for slots this session hasn't
touched, memoized back into `lastModified` once read. `WallOfFameView.heroCardSlot(forGridSize:)`
renders that slot like any other card, or a `.bestMoves(size)`-labeled empty slot if neither
record has ever been set.

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
  18pt + `Color.black.opacity(0.45)` tint; the twinkling sparkles are drawn on top by the
  board-level `PuzzleFogLayer` (see below), not per tile.
- **Frosted glass** (`isFogMode && !tile.isLocked && isDragging`): blur drops to 3pt, tint
  and sparkles hidden — the image is barely readable while a tile is in motion.
- **Revealed** (`tile.isLocked`): no blur, no overlay; transitions from fog over 1.2s
  easeInOut.

The sparkle field is a `Canvas` particle routine (`FogField.draw(in:context:seed:time:)`):
each frame it draws N twinkling ellipses inside a rect whose brightness oscillates via
`sin(time * freq + phase)`. A `seed` (passed as `Float(tile.id)`) offsets the particle index
sequence by `seed × 1000`, making each tile's star field visually distinct without any
per-instance state; particle count scales with rect area (`max(640, Int(area / 6.875))`) and
`time` comes from `timeline.date.timeIntervalSince1970` (large absolute value — fine since
`sin()` is periodic and only brightness oscillates, not position).

**Performance (July 2026 pass):** the board originally mounted one `FogTileOverlay` — its own
`TimelineView(.animation)` + `Canvas` — *per unrevealed tile*, i.e. up to ~63 independent
60 fps particle loops on an 8×8 board. That collapsed into a single board-level
`PuzzleFogLayer`: one `TimelineView` capped at **30 fps** drives one `Canvas` that iterates
every unrevealed, non-dragging tile and calls `FogField.draw` per cell — the same
one-shared-timeline shape the Wall of Fame swing engine already uses (`WallOfFameSwingDriver`).
`TileView` keeps only the per-tile blur + dark scrim (which correctly track the transient drag
state); `FogTileOverlay` survives as a standalone overlay for the Fog Mode preview card.

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

**Quick Snap** (shipped July 2026): a new `.camera` `MediaSourceType` rather than a new
`GameMode` — underneath it plays plain Swap. Selecting it in `MediaSourcePickerView` (only
offered when `QuickSnapCameraSession.isCameraAvailable`) makes "Play" open a full-screen
`QuickSnapCameraView` instead of pushing the puzzle. That view wraps a `@MainActor @Observable`
`QuickSnapCameraSession` (an `AVCaptureSession`) bridged to SwiftUI through `CameraPreviewView`,
overlaid with a countdown ring that recolors under pressure like the streak timer. The whole
viewfinder is a tap-to-snap shutter (skips the countdown, Fitness-app style); otherwise the
frame is captured automatically at zero. Each second down fires a `.selection` haptic and the
capture a firmer `.impact`, both gated on `SettingsStore.hapticsEnabled`. The countdown length
is its own preference — `SettingsStore.quickSnapDuration` (3/5/10s via
`QuickSnapDurationPickerView`, read through `GameSession.currentQuickSnapDuration`) — no longer
piggybacking on `previewDuration`. On capture, `GameSession.enterQuickSnapMode(with:)` follows
the same transient-flag pattern as Daily: it forces `.swap`, saves the player's prior mode, and
stores the `CGImage` so `startNewGame()` slices it directly (bypassing `ImageService`) and skips
the "memorize the image" preview. Quick Snap counts toward Swap stats/streaks with no exemption.
"Play Again" from the completion banner re-opens `QuickSnapCameraView` (presented by `PuzzleView`
this time) so each round is a fresh shot; `refreshQuickSnapImage(with:)` swaps in the new frame
without disturbing the saved pre-Quick-Snap mode. `leaveGame()` restores that mode and clears
the flag, so a force-quit mid-game resumes as an ordinary Swap game.

**Live Activity + Dynamic Island** (shipped July 2026): a "puzzle in progress" Live Activity
(`PuzzleLiveActivity` in the widget extension) showing the board, mode, moves/time, streak,
and a progress ring on the Lock Screen and in the Dynamic Island.
`Services/LiveActivityController.swift` owns the lifecycle — `GameSession` calls
`start` on game start, `refresh` when the app backgrounds (the moment the Lock Screen becomes
visible), and `end` on solve/fail/leave. Only small counters travel in
`PuzzleActivityAttributes.ContentState`; the board itself is a PNG (`board-<UUID>.png`,
fresh name per update to bust the widget's image cache) written to the App Group container
via `PuzzleBoardSnapshot.pngData(...)` with
`.completeFileProtectionUntilFirstUserAuthentication` so the Lock Screen can read it while
locked. A 1-hour `staleDate` plus `reconcileLiveActivityOnLaunch()` handle force-quit
orphans (no code runs after a kill; next launch reaps strays).

**Home-screen widgets + deep links** (shipped July 2026): three widgets in the same
extension, all systemSmall/Medium only (Lock Screen accessory families were tried on the
Daily widget and removed — home screen only) — Daily Challenge, Streaks & Records
(configurable via `AppIntentConfiguration` with widget-local `WidgetGameMode`/
`WidgetGridSize` AppEnums — Zen omitted since it tracks nothing), and Resume Puzzle (board
snapshot + progress + empty state). All three force `.colorScheme(.dark)` on their content
in the widget configuration closure, so the card stays dark-only regardless of iOS's
per-widget light/dark appearance setting — without it, that system setting flips
`.primary`/`.secondary` to their light values while the custom dark `containerBackground`
stays fixed, making text unreadable.

*Data flow*: the extension can't read `UserDefaults.standard`, so widget-visible state is
mirrored as one Codable `WidgetSnapshot` (sections `daily` / `modeStats` / `resume`, each
optional so old/new snapshots stay mutually decodable) in the App Group defaults through
`Shared/WidgetDataStore.swift`. All writes go through `Services/WidgetDataController.swift`
(owned by `GameSession`, mirroring how `LiveActivityController` is wired): each update
rewrites one section, skips the save+reload when the section is unchanged (`Hashable`
diffing), and reloads only that section's kind via
`WidgetCenter.shared.reloadTimelines(ofKind:)` using the shared `WidgetKind` constants.
Hooks fire at game start / solve / fail / leave / background / Settings reset — **never per
move**, because `StatsStore.currentStreak` increments on every correct move and per-move
reloads would burn the WidgetKit refresh budget. The controller no-ops when the App Group is
unavailable, and `GameSession` passes it `nil` defaults when its own `PersistenceStore`
isn't real `UserDefaults`, keeping unit tests hermetic.

*Timelines*: Streaks & Records and Resume use a single entry with policy `.never` — their
data only changes through app play, which reloads them explicitly. The Daily widget is the
exception: it computes today's grid/mode itself via the target-shared
`DailyChallengeSeeder` and emits a second entry at the next midnight (policy
`.after(midnight)`), so "done today" flips off and the new day's identity appears with no
app process running; the snapshot only carries completion/streak facts. Displayed streak
drops to 0 when `lastCompletedDay` is older than yesterday, mirroring
`advanceCalendarStreak`'s reset semantics.

*Resume board PNG*: a separate `widget-board-<UUID>.png` pipeline in the controller rather
than reusing the Live Activity's snapshots — those are deleted on every refresh and on
`end()`, exactly when the Resume widget still needs a stable image. Same
fresh-UUID-then-delete-previous discipline, so at most one stale file ever lingers. Numbers
games have no picture: `boardImageName` is `nil` and the widget's `ResumeBoardThumbnail`
falls through to the puzzle-glyph placeholder (it also applies
`widgetAccentedRenderingMode(.accentedDesaturated)` so tinted Home Screens desaturate the
photo instead of blanking it — the reason it's a widget-local sibling of `BoardThumbnail`
rather than a change to the Live Activity's view).

*Deep links*: `Shared/DeepLink.swift` defines `ninetilespuzzle://daily`, `…://resume`, and
`…://mode/<rawValue>/<size>` (size optional, validated 3…8); the scheme lives in the app's
`Info.plist` `CFBundleURLTypes`. `MenuView` handles them in `.onOpenURL` →
`handleDeepLink(_:)`: every route dismisses covering sheets and pops to the menu first.
Resume needs special handling because `PuzzleView`'s lifecycle unconditionally wipes the
board and starts a fresh game — `GameSession.requestResume()` sets a one-shot
`pendingResume` flag that `PuzzleView.onAppear` consumes to keep the restored board and
restart its timers (`startTimersForRestoredGameIfNeeded()`, extracted from
`restoreFromUserDefaults()`) instead. Two in-game taps short-circuit to "keep playing"
(resume while playing, daily while already in today's daily); any other in-game route waits
600ms after popping so the outgoing `PuzzleView`'s `onDisappear → leaveGame()` (which resets
the transient daily/Quick Snap flags) can't clobber the new route's setup. The `.mode` route
lands on the configured menu rather than auto-starting, since play is gated by mode
specifics (Quick Snap capture, ladder stages) the menu already handles.

*Target sharing gotchas*: files shared with the extension are listed in
`membershipExceptions` of the `PBXFileSystemSynchronizedBuildFileExceptionSet` in
`project.pbxproj` — Xcode silently drops entries whose files don't exist on disk yet, so
create the file before (or with) the pbxproj edit. The app target sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so shared types referenced from nonisolated
contexts (`WidgetDataStore`, `WidgetSnapshot`, `WidgetKind`, `LiveActivityStore`) are
explicitly `nonisolated`.

**Wall of Fame** (shipped June 2026): a cork-board view where every personal best is
automatically captured and pinned as a polaroid card. `PuzzleView` renders `ShareCardView`
via `ImageRenderer` at 3× scale at the moment a record is set, converts the result to a
`CGImage`, and calls `WallOfFameStore.save(_:for:)`. As of the July 2026 perf pass this render
(and the solved-puzzle share PNG) runs inside a `Task` rather than synchronously in the
`.onChange` handler, and `PuzzleView` caches the share PNG in `@State` rather than re-running
`ImageRenderer` on every body pass while the completion banner is on screen. `WallOfFameStore`
writes a PNG to
`Documents/wall_of_fame/<slot>.png` using `CGImageDestinationCreateWithData` / ImageIO
(no UIKit, compatible with `ShareLink`'s `URL`-based `Transferable` requirement); the
in-memory `[WallOfFameSlot: CGImage]` cache avoids repeated disk reads within a session.

`WallOfFameView` is a `ZStack` containing three sibling layers:
1. `ScrollView` — the cork board with six `LazyVGrid` sections (Difficulty Highlights, Best
   Moves, Fastest Solve, Daily Challenge, Streaks, Gauntlet Ladder).
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
gameMode)` stats use string-keyed lookups built from a `3...8 × GameMode.allCases` loop.
`GameSession` splits its save path in two (July 2026 perf pass): `saveDynamicState()` writes
only the per-move state (tiles JSON + counters/flags) and is what `registerMove()` calls after
every move, while `saveToUserDefaults()` layers the expensive source-image JPEG re-encode on
top and runs only when the image actually changes — once per new game. Previously every tile
tap re-encoded the full image; now that cost is paid once. Both reuse one shared
`JSONEncoder`/`JSONDecoder`. No SwiftData yet (flagged in `ROADMAP.md` §4 as the natural next
step once stats history/charts are wanted).

**Testing**: `NineTilesPuzzleTests` is a real Unit Testing Bundle target (added manually in
Xcode in June 2026 — it existed as a folder of source files for a while before that without
ever actually being wired up or compiled). 169 `@Test` functions currently pass, covering: both engines
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
reconstruct a second `GameSession` and read back) isn't exercised for the Gauntlet Ladder's
`.numbers`-media session shape, so that persistence test instead asserts directly against the
in-memory `PersistenceStore` fake. `GameSessionPersistenceTests` (added in the July 2026 perf
pass) does get a true write→reconstruct round-trip by using `.random` (image-backed) media
instead of `.numbers`, letting it assert the sliced `tileImages` are rebuilt on restore; it
also pins the new static/dynamic save split (`saveDynamicState()` never touches the image key,
`saveToUserDefaults()` does). The widget work (July 2026) added three suites:
`WidgetSnapshotTests` (JSON round-trip, missing-optional-sections tolerance,
`WidgetDataStore` save/load through a throwaway `UserDefaults` suite, corrupt-data
resilience), `DailyChallengeSeederTests` (same-calendar-day determinism — what the Daily
widget's precomputed midnight entry relies on — pool membership, cross-day variety, seeded
derangement and slide-board permutation validity), and `DeepLinkTests` (URL round-trips for
every route plus ten malformed-URL rejections). Getting the target wired up surfaced three real,
previously-undetected bugs that had been sitting in untested code paths — two missing
imports and one test with a geometrically-invalid fixture (asserted a slide between two
non-adjacent grid cells) — all fixed once the target could finally compile and run them.
