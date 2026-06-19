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
├── NineTilesPuzzleApp.swift        — @main, builds PuzzleState + SoundService, splash screen
├── Models/
│   ├── PuzzleState.swift           — the app's single @Observable state object (see below)
│   ├── PuzzleState+Achievements.swift
│   ├── PuzzleState+Settings.swift
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
NineTilesPuzzleApp
   └─ injects PuzzleState + SoundService into the environment (app-wide singletons)
        │
        ▼
MenuView ── NavigationStack(GameRoute) ──▶ PuzzleView / GameModeView / StatsView / ...
        │
        ▼
PuzzleState (@Observable, @MainActor)
   • owns: tiles, images, mode/settings, streaks, move/time records, achievements, timers
   • owns instances of: ClassicEngine, SlideEngine
   • talks directly to: UserDefaults, ImageService, ImageSlicer, AchievementService
        │
        ├─ selectedGameMode ──▶ activeEngine (computed: .slide → SlideEngine, else Classic)
        │                              │
        │                  shuffle() / isSolved()   (shared GameEngine protocol)
        │                  swap() / slide()         (mode-specific, called directly by PuzzleState)
        │
        └─ persistence: manual UserDefaults get/set per field, JSON-encoded tiles + JPEG image
```

**`PuzzleState`** is the only `@Observable` model in the app (besides the per-tile
`TileModel` and `SoundService`). Every view that needs game state, settings, stats, or
achievements reads from this one object via `@Environment(PuzzleState.self)`. It currently
owns five distinct concerns in one type: live game session, user settings, stats/records,
achievements, and persistence — see `ROADMAP.md` §6 for the specific scaling gap this
creates as more game modes are added.

**Game modes today**: `GameMode` is 7 cases, but `isAvailable` gates 3 of them
(`.classic`, `.slide`, `.zen`); the other 4 are listed in the UI as "Coming soon…" with no
behavior. Mode-specific behavior is currently expressed as scattered conditionals
(`isZenMode`, `selectedGameMode == .slide`, `debugOverlayEnabled`) inside `PuzzleState` and
`PuzzleView`/`PuzzleGridView`, rather than through a single abstraction.

**Image pipeline**: `ImageSource` protocol → `RemoteImageSource` (picsum.photos) /
`PhotoLibraryImageSource` / `LocalImageSource` (bundled fallback) → `ImageService` (primary
+ fallback on `URLError`) → `ImageSlicer` (center-crop + slice into per-tile `CGImage`s,
stored in `PuzzleState.tileImages`).

**Persistence**: everything lives in `UserDefaults` — settings, in-progress tile state
(JSON), the in-progress source image (JPEG-encoded), and per-`(gridSize, gameMode)` stats
(personal best moves/time, games played) via string-keyed lookups built from a nested
`3...8 × GameMode.allCases` loop. No SwiftData yet (flagged in `ROADMAP.md` §4 as the
natural next step once stats history/charts are wanted).

**Testing**: `NineTilesPuzzleTests` covers the stateless/testable layer well — both engines,
`SlideSolver`, `ImageService`, `ImageSlicer`. `PuzzleState` itself has no tests; it's
tightly coupled to `UserDefaults` and constructs its own engine/service instances
internally, which makes it hard to test in isolation today.
