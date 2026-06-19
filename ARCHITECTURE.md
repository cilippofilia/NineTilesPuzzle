# NineTilesPuzzle — Architecture Overview

Snapshot of the current codebase structure, as of 2026-06-19. ~4,300 lines of Swift across
~50 files. This is a descriptive document — see the bottom of `ROADMAP.md` (§6) for the
known architectural gap around game modes, and ask for the architecture-improvement
discussion for forward-looking recommendations.

## Tech stack

- SwiftUI, iOS only, dark-mode-locked (`.preferredColorScheme(.dark)`)
- `@Observable` classes for shared state (no `ObservableObject`/Combine)
- Swift Concurrency throughout (`async/await`, structured `Task`s) — no GCD
- Persistence: `UserDefaults` only, no SwiftData/CloudKit yet
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
│   ├── StatsKey.swift              — Hashable(gridSize, gameMode) used by GameSession/StatsStore
│   ├── GameMode.swift              — enum: classic/slide/timeTrial/limitedMoves/zen/fog/chaos
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
│   │   ├── PuzzleView.swift         — game screen orchestrator (largest view, ~340 lines)
│   │   ├── PuzzleGridView.swift     — tile layout, drag handling, slide/swap dispatch
│   │   ├── TileView.swift           — single draggable tile
│   │   ├── ImagePreviewView.swift   — pre-shuffle reveal
│   │   ├── PuzzleStatusBarView.swift, MoveCounterView.swift, TimeCounterView.swift
│   │   └── PuzzleErrorView.swift
│   └── Helpers/                     — grab-bag of small reusable views (toast, banners,
│                                       loading/splash, brand mark, badges, zen sparkle)
├── Resources/                       — achievements.json, sounds, asset catalog, app icon
NineTilesPuzzleTests/                 — engine/solver/image-service/image-slicer unit tests
```

## Core data flow

```
NineTilesPuzzleApp.init()
   constructs, in dependency order:
     StatsStore()  SettingsStore()  AchievementsStore()  ──▶  GameSession(stats:, achievements:, settings:)
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
   • depends on (read-only): StatsStore, AchievementsStore, SettingsStore
   • talks directly to: UserDefaults (its own keys), ImageService, ImageSlicer
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
(`PuzzleState`) owning all five concerns — split in June 2026 (see `ROADMAP.md` §6, which
diagnosed the gap, and the conversation that did the split). Why the boundaries fell where
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

**Game modes today**: `GameMode` is 7 cases, but `isAvailable` gates 3 of them
(`.classic`, `.slide`, `.zen`); the other 4 are listed in the UI as "Coming soon…" with no
behavior. Mode-specific behavior is still expressed as scattered conditionals (`isZenMode`,
`selectedGameMode == .slide`, `settingsStore.debugOverlayEnabled`) inside `GameSession` and
`PuzzleView`/`PuzzleGridView` — the store split didn't address this axis, since with only
Zen as a real data point any `GameModeRules`-style abstraction would be guessing at shape
(see `ROADMAP.md` §6's closing note). Worth revisiting once Time Trial or Limited Moves
actually exists.

**Image pipeline**: `ImageSource` protocol → `RemoteImageSource` (picsum.photos) /
`PhotoLibraryImageSource` / `LocalImageSource` (bundled fallback) → `ImageService` (primary
+ fallback on `URLError`) → `ImageSlicer` (center-crop + slice into per-tile `CGImage`s,
stored in `GameSession.tileImages`).

**Persistence**: still `UserDefaults` only, but each store now owns and persists only its
own keys (no more single 400-line file mixing all of them). `StatsStore`'s per-`(gridSize,
gameMode)` stats use string-keyed lookups built from a `3...8 × GameMode.allCases` loop. No
SwiftData yet (flagged in `ROADMAP.md` §4 as the natural next step once stats history/charts
are wanted) — and no repository/protocol seam yet either, so each store still calls
`UserDefaults.standard` directly (a deliberately deferred follow-up, not an oversight).

**Testing**: `NineTilesPuzzleTests` covers the stateless/testable layer well — both engines,
`SlideSolver`, `ImageService`, `ImageSlicer`. The four stores have no tests yet, but are now
small enough and decoupled enough (especially `StatsStore` and `AchievementsStore`, which
have zero UI coupling) to actually write unit tests against, unlike the old `PuzzleState`.
