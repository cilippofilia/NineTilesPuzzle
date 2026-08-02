# NineTilesPuzzle — Architecture Overview

Snapshot of the current codebase structure, as of 2026-08-02 (updated for Wall of Fame +
Stats→Settings, a July 2026 performance pass, the Live Activity, home-screen widgets + deep
links, the power-up economy, Challenge Friends, the July 2026 `Models/` feature-folder
restructure, the Daily Challenge widget/reminder-notification follow-ups, the Time Trial
resume grace period, Wall of Fame manual curation, Challenge Friends being gated behind
a Settings toggle — along with the matching Achievements gating — the Hard-Feature Gate
monetization system including its 2026-07-19 StoreKit 2 paywall rebuild, a 2026-08-02 fix so
Quick Snap no longer overrides the player's chosen `GameMode`, and the Billboard cross-promo
ads shipped the same day). This is a
descriptive document — see this file's own §6 resolution below (and `ROADMAP.md` §6, kept in
sync with it) for how the "does mode-specific behavior need a shared abstraction" question was
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
- A QuickLook thumbnail extension target (`NineTilesPuzzleThumbnailExtension`) rendering
  rich Files/Messages/Finder previews for shared `.ntpchallenge` files (see Challenge Friends
  below); shares a few `Models/Challenge/` files with the main app target the same way
- Swift Testing (not XCTest) for unit tests
- One third-party dependency: [Billboard](https://github.com/hiddevdploeg/Billboard) (SPM,
  MIT), used for the free-tier cross-promo ad — see Monetization / Hard-Feature Gate below

## Directory layout

```
NineTilesPuzzle/
├── NineTilesPuzzleApp.swift        — @main, constructs StatsStore, SettingsStore,
│                                    AchievementsStore, DailyChallengeStore, WallOfFameStore,
│                                    MotionManager, SoundService, GameCenterService;
│                                    injects all into the environment; kicks off GC auth via .task
├── Models/                          — reorganized July 2026 from one flat folder into
│   │                                  feature subfolders (paths below reflect this; the
│   │                                  `Achievemnts/` folder name keeps that exact typo — it's
│   │                                  the real on-disk name, not a doc error)
│   ├── GameModes/
│   │   ├── GameSession.swift        — the game currently configured/in progress (see below)
│   │   ├── GameMode.swift           — enum: classic/slide/timeTrial/limitedMoves/zen/fog/chaos
│   │   ├── TileModel.swift          — @Observable tile: id, currentIndex, isLocked
│   │   ├── TimeTrialRules.swift     — pure constants/formulas: base time limit per grid size,
│   │   │                              combo bonus/misplay penalty, score (see below)
│   │   ├── GauntletLadderRules.swift — pure 10-stage table + ladder scoring (see below);
│   │   │                              deliberately separate from TimeTrialRules.swift
│   │   ├── LimitedMovesRules.swift  — pure per-grid-size move budget table (see below)
│   │   ├── ChaosTransform.swift     — pure whole-image orientation/tone/posterize/pixelate
│   │   │                              transform for Chaos Mode (see below)
│   │   └── SeededShuffle.swift      — seeded-derangement-shuffle primitives extracted out of
│   │                                  DailyChallengeSeeder so Challenge Friends (below) can
│   │                                  reuse them for an arbitrary (not date-derived) seed
│   ├── Stats/
│   │   ├── StatsStore.swift         — personal bests, games played, streaks (keyed by StatsKey)
│   │   └── StatsKey.swift           — Hashable(gridSize, gameMode) used by GameSession/StatsStore
│   ├── Settings/
│   │   ├── SettingsStore.swift      — app prefs unrelated to "which game": preview/streak
│   │   │                              countdown durations, Quick Snap timer, haptics, debug
│   │   │                              overlay, powerUpsEnabled/debugInfinitePowerUps
│   │   └── PersistenceStore.swift   — protocol seam over UserDefaults (see below)
│   ├── Calendar/
│   │   ├── DailyChallengeStore.swift — daily-challenge-specific stats: calendar streak,
│   │   │                              best calendar streak, last completed date, daily
│   │   │                              best moves/time. Fully independent of StatsStore.
│   │   ├── DailyChallengeSeeder.swift — pure enum: date→UInt64 seed, seeded picsum URL
│   │   │                              (/seed/ntp-YYYY-MM-DD/1024/1024), deterministic
│   │   │                              derangement shuffle via xorshift64 PRNG (SeededGenerator)
│   │   ├── DailyDayRecord.swift     — per-day moves/time/streak record backing the calendar's
│   │   │                              tap-to-polaroid share card
│   │   └── DailyCalendarMonth.swift — pure month-grid math for the history calendar view
│   ├── Achievemnts/
│   │   ├── AchievementsStore.swift  — achievement definitions, unlock checks, remote refresh
│   │   ├── Achievement.swift        — Codable definition: id, title, systemImage, category,
│   │   │                              metric, target, comparison, isUnlocked, unlockedDate
│   │   ├── AchievementCategory.swift — 7-case enum (milestones/difficulty/efficiency/
│   │   │                              streaks/explorer/social/special); drives AchievementsView
│   │   │                              sections — `.social` added for Challenge Friends
│   │   ├── AchievementMetric.swift  — what a target is measured against; encodes as a dotted
│   │   │                              string (e.g. "personalBestMoves.3.swap") for hand-editable
│   │   │                              JSON; value(in:justSolved:now:) reads StatsStore, and
│   │   │                              now also takes a ChallengeStore for
│   │   │                              .challengesSent/.challengesWon/.challengesPlayed
│   │   └── AchievementComparison.swift — greaterThanOrEqual | lessThanOrEqual
│   ├── WallOfFame/
│   │   ├── WallOfFameSlot.swift     — 25-case enum: bestMoves(3…8), bestTime(3…8),
│   │   │                              dailyBestMoves, dailyBestTime, calendarStreak,
│   │   │                              ladderStage(1…10); exposes fileName, displayTitle, seedValue
│   │   └── WallOfFameStore.swift    — @Observable, @MainActor; persists card PNGs to
│   │                                  Documents/wall_of_fame/<slot>.png via ImageIO (no UIKit);
│   │                                  caches CGImages in memory; exposes cardImage(for:),
│   │                                  save(_:for:) (disk write off main actor), fileURL(for:);
│   │                                  also persists manual curation — isHidden/setHidden and
│   │                                  orderedSlots/move (see Wall of Fame below)
│   ├── PowerUps/                    — power-up economy (shipped 2026-07-07, see below)
│   │   ├── PowerUpType.swift        — 5-case enum: peek/autoPlace/hint/streakFreeze/reshuffle
│   │   │                              — title/icon/color per case
│   │   ├── PowerUpStore.swift       — @Observable, @MainActor inventory: earn/consume/
│   │   │                              earnRandom()/resetToDefaults(), UserDefaults-backed
│   │   └── PowerUpRules.swift       — tuning constants: peek/hint duration, streak-milestone
│   │                                  interval (5), starting inventory (3 of each)
│   ├── Challenge/                   — Challenge Friends feature (shipped 2026-07-08, see below)
│   │   ├── FriendChallenge.swift    — the self-contained wire payload: mode, grid size, seed,
│   │   │                              sender's JPEG image, sender's moves/time,
│   │   │                              parentChallengeID (Rechallenge chains), formatVersion
│   │   ├── ChallengeResult.swift    — reply payload (opponent's moves/time) for the result
│   │   │                              round-trip
│   │   ├── ChallengeRecord.swift    — persisted history entry (direction-agnostic
│   │   │                              creatorMoves/opponentMoves, outcome)
│   │   ├── ChallengeStore.swift     — @Observable, @MainActor; UserDefaults JSON + on-disk
│   │   │                              JPEGs (Documents/challenges/<id>.jpg), 200-record
│   │   │                              history cap, determineOutcome win/lose/tie logic
│   │   ├── ChallengeComposer.swift  — builds a FriendChallenge from a just-finished game
│   │   ├── ChallengeImageCodec.swift — JPEG encode/decode helpers shared by both transports
│   │   └── ChallengeFilePayload.swift — `.ntpchallenge` Transferable file wrapper; also
│   │                                  defines the `ChallengePayload` envelope
│   │                                  (invite/result) and `ChallengeFileCoder`'s
│   │                                  `Result<ChallengePayload, DecodeFailure>` decode path
│   │                                  (.unreadable/.corrupted/.unsupportedFormatVersion)
│   ├── Helpers/
│   │   ├── ZenSparkle.swift         — decorative particle model for Zen mode's solve animation
│   │   ├── Bundle-Decodable-Ext.swift
│   │   ├── Int-Formatting-Ext.swift
│   │   └── TimeInterval-Formatting-Ext.swift
│   └── Image/
│       ├── MediaSourceType.swift   — enum: random/local/mixed/numbers/camera
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
│   ├── GameCenterService.swift     — @Observable, handles GKLocalPlayer authentication;
│   │                                 exposes isAuthenticated + showDashboard() which
│   │                                 triggers the native Game Center UI via
│   │                                 GKAccessPoint.trigger(handler:) (the iOS 26 replacement
│   │                                 for the deprecated GKGameCenterViewController); no
│   │                                 leaderboard/achievement submission wired up yet
│   ├── PuzzleBoardSnapshot.swift   — renders the board to a PNG (ImageRenderer) for both the
│   │                                 Live Activity and the Resume widget's board thumbnail
│   ├── ChallengeNearbySession.swift — Network.framework nearby transport for Challenge
│   │                                 Friends (see below); NWListener/NWBrowser/NWConnection
│   │                                 over a Bonjour `_ntp-challenge._tcp` service, replacing
│   │                                 an earlier Multipeer Connectivity implementation
│   └── DailyReminderService.swift  — UNUserNotificationCenter wrapper scheduling the daily
│                                     reminder local notification (see below)
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
│   │                                  (moved here from GameModeView), WidgetsGuideView,
│   │                                  PowerUpsGuideView
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
│   │   ├── PuzzleErrorView.swift
│   │   ├── PuzzlePowerUpToolbarView.swift — in-game row of PowerUpBadgeButtons (Peek/
│   │   │                              Auto-place/Hint/Streak Freeze/Re-shuffle), each
│   │   │                              disabled when its type is inapplicable to the
│   │   │                              current mode/media (see Power-ups below)
│   │   ├── PowerUpBadgeButton.swift — single power-up button: icon, owned count, tap to use
│   │   └── EarnedPowerUpBadgeView.swift — transient "+1 Peek" style toast played off
│   │                                  PowerUpStore.recentlyEarned after a streak
│   │                                  milestone/achievement/Daily completion
│   ├── Daily/
│   │   ├── DailyChallengeCardView.swift — menu card: today's date, calendar streak,
│   │   │                              "Play" button (or "Done ✓" once completed); tapping
│   │   │                              the card (not the Play button) opens the calendar below
│   │   ├── DailyStreakBadgeView.swift — small flame+streak badge reused by the menu card
│   │   ├── DailyChallengeCalendarView.swift — Locket-style month-grid of past completions
│   │   ├── DailyMonthGridView.swift — one month's grid of DailyDayCellViews + month math
│   │   │                              from Models/Calendar/DailyCalendarMonth.swift
│   │   └── DailyDayCellView.swift  — completed (golden square) / missed (circle) / upcoming
│   │                                  (faint square) cell; completed cells are tappable to
│   │                                  zoom that day's rebuilt share card and replay
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
│   ├── Challenge/                    — Challenge Friends UI (see below)
│   │   ├── ChallengeHomeView.swift  — menu entry: send-a-challenge launcher + history list
│   │   ├── ChallengeHistoryListView.swift — full history (ChallengeHistoryRow: 44pt puzzle
│   │   │                              photo thumbnail, direction badge, "To "/"From " prefix)
│   │   ├── ChallengeSendSheet.swift — compose + share a `.ntpchallenge` from a finished game
│   │   ├── ChallengeInviteView.swift — receiving device's accept/decline screen
│   │   ├── ChallengeOutcomeView.swift — win/lose/tie comparison; "Send Result Back" button
│   │   │                              for the file-transport manual reply path
│   │   ├── ChallengeResultSendSheet.swift — manual result-reply sheet (mirrors
│   │   │                              ChallengeSendSheet, no image/mode/grid to package)
│   │   └── Nearby/
│   │       ├── NearbyPeerPickerView.swift — Bonjour peer discovery/picker
│   │       └── NearbyChallengeView.swift — send/receive UI over ChallengeNearbySession;
│   │                                  stays open post-send to show the live auto-reply result
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
│                                       no Lock Screen accessory families); redesigned
│                                       2026-07-12 (Duolingo-style streak row, "battery charge"
│                                       date chip on medium) with DailyChallengeConfigurationIntent
│                                       (WidgetConfigurationIntent — "Show Puzzle Photo" toggle,
│                                       off by default) and DailyChallengeProvider
├── StreaksRecords/                  — AppIntent configuration (WidgetGameMode/WidgetGridSize
│                                       AppEnums, StatsConfigurationIntent) + widget + views
├── ResumeGame/                      — widget + views incl. ResumeBoardThumbnail (accented-mode
│                                       desaturation wrapper around the board image)
└── Views/                           — Live Activity presentation (PuzzleLiveActivity, Lock Screen
                                        card, Dynamic Island — both gained `.widgetURL` to the
                                        `…://resume` deep link 2026-07-16) + shared pieces
                                        reused by the widgets: StatBadge, ProgressRing,
                                        ProgressBar, ModeGlyphBadge, BoardThumbnail, BrandPuzzleMark
NineTilesPuzzleThumbnail/             — QuickLook thumbnail extension target
                                        (NineTilesPuzzleThumbnailExtension, added 2026-07-09)
└── ThumbnailProvider.swift          — QLThumbnailProvider rendering a branded gradient card
                                        (challenge's embedded photo, or an SF Symbol badge for
                                        an imageless `.result` reply) directly into the
                                        QuickLook-provided CGContext for Messages/Files/Finder
                                        previews of shared `.ntpchallenge` files; shares
                                        Models/Challenge/*, GameMode.swift from the app target
NineTilesPuzzleTests/                 — real, wired-up Unit Testing Bundle target (see below)
```

## Core data flow

```
NineTilesPuzzleApp.init()
   constructs, in dependency order:
     StatsStore()  SettingsStore()  AchievementsStore()  DailyChallengeStore()
     PowerUpStore()  ChallengeStore()  ──▶  GameSession(statsStore:, achievementsStore:,
                                              settingsStore:, dailyChallengeStore:,
                                              powerUpStore:, challengeStore:)
     WallOfFameStore()  MotionManager()  SoundService()  GameCenterService()
     DailyReminderService()
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
   • depends on (read-only): StatsStore, AchievementsStore, SettingsStore, DailyChallengeStore,
     PowerUpStore, ChallengeStore, PersistenceStore
   • talks directly to: PersistenceStore (its own keys), ImageService, ImageSlicer
        │
        ├─ selectedGameMode ──▶ activeEngine (computed: .slide → SlideEngine, else Classic)
        │                              │
        │                  shuffle() / isSolved()   (shared GameEngine protocol)
        │                  swap() / slide()         (mode-specific, called directly by GameSession)
        │
        └─ registerMove() reports completions/streaks to StatsStore, then asks
           AchievementsStore.checkAchievements(using:challengeStore:) to re-evaluate unlocks,
           and awards power-ups (streak milestone / achievement unlock / Daily completion)
```

**Six stores, one dependency direction.** `GameSession` is the only one with dependencies
(`StatsStore`, `AchievementsStore`, `SettingsStore`, `DailyChallengeStore`, `PowerUpStore`,
`ChallengeStore`, all injected at init); the others know nothing about each other or about
`GameSession`. This used to be a single god object
(`PuzzleState`) owning all five concerns — split in June 2026. Why the boundaries fell where
they did:
- **`GameSession`** owns `gridSize`/`mediaSourceType`/`selectedGameMode` (not `SettingsStore`)
  because changing them must synchronously clear the in-progress board — keeping that inside
  one type avoids needing cross-store reactive wiring.
- **`StatsStore`** doesn't know "current" anything (no grid size, no selected mode) — it only
  answers questions keyed by `StatsKey`. `GameSession` exposes the "for current size/mode"
  convenience accessors (`currentStreakForCurrentSize`, `classicBestMovesForCurrentSize`, …)
  since it's the one place that knows what "current" means.
- **`AchievementsStore.checkAchievements(using:challengeStore:justSolved:)`** takes
  `StatsStore` (and, since Challenge Friends, `ChallengeStore`) as parameters rather than
  holding permanent references, so it stays decoupled and easy to test with fake stats.
  The check is fully data-driven: for each `Achievement` in the list (loaded from
  `achievements.json` via `AchievementService`), it calls `metric.value(in: stats)` and
  compares against `target` using `comparison` — no hardcoded per-id `switch`. The
  Completionist achievement is the one exception: it's skipped in the generic loop and handled
  by `updateCompletionistAchievement`, since "all others unlocked" depends on the list itself.
  `AchievementsView` groups rows into sections by `AchievementCategory` — reading the
  precomputed `AchievementsStore.achievementsByCategory(challengeFriendsEnabled:)` (one O(n)
  grouping) and `unlockedCount(challengeFriendsEnabled:)` rather than re-filtering the array
  per category on every render, a July 2026 perf tidy-up. `AchievementRowView` reads
  `StatsStore` from the environment to render inline progress for count-based achievements
  (≥, target > 1) and a best-moves hint for efficiency achievements (≤).

  **Challenge Friends gating (2026-07-16):** `checkAchievements` also takes a
  `challengeFriendsEnabled: Bool = true` parameter (`GameSession` passes
  `settingsStore.challengeFriendsEnabled`). `AchievementMetric.isChallengeFriendsMetric` flags
  the three metrics reading `ChallengeStore` (`.challengesSent`/`.challengesWon`/
  `.challengesPlayed`); while disabled, the generic loop skips evaluating them entirely (so
  they can't unlock in the background), and `updateCompletionistAchievement` excludes them
  from its "every other achievement" requirement too, so Completionist stays reachable without
  the player ever touching Challenge Friends. `visibleAchievements(challengeFriendsEnabled:)`
  is the single filter both `unlockedCount`/`achievementsByCategory` and `AchievementsView`
  build on, so the three Challenge Friends achievements (`firstChallengeSent`,
  `firstChallengeWon`, `challengeChampion`) simply don't appear — list, tally, and Completionist
  math all agree — while the feature is off, and `AchievementsView` skips rendering a category
  section (e.g. "Social") left with zero visible achievements rather than showing a bare
  header. Achievements themselves are never gated as a whole — only this Challenge-Friends-
  scoped subset, matching the fact that Challenge Friends the feature is itself hidden behind
  a Settings toggle (see Challenge Friends below).

**`PersistenceStore`** (`Models/Settings/PersistenceStore.swift`) — a minimal protocol mirroring the
handful of `UserDefaults` methods the stores actually use (`set`/`object`/`string`/
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
empties the clock. `Models/GameModes/TimeTrialRules.swift` holds the pure, table-driven constants
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
unaffected. `Models/GameModes/GauntletLadderRules.swift` holds the 10-row stage table and a distinct
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

**Time Trial / Gauntlet Ladder resume grace period** (shipped 2026-07-16): `PuzzleView`'s
`.onChange(of: scenePhase)` now distinguishes three phases instead of two. `.background` (a
real backgrounding) and `.inactive` (a phone call, Face ID prompt, Control Center, or the
app-switcher preview — none of which used to pause anything, since only `.background` was
handled before) both cancel any in-flight resume countdown and call `session.pauseTimers()`;
`.background` additionally calls `refreshLiveActivity()` after pausing so the Lock Screen
reminder shows the exact board/elapsed-time the player left behind. Returning to `.active`
only calls `session.resumeTimers()` immediately for non-Time-Trial games; for an unsolved,
unfailed Time Trial or Gauntlet Ladder run with time still on the clock, it instead calls
`PuzzleView.beginResumeCountdown()`, which drives `@State private var
isShowingResumeCountdown`/`resumeCountdownValue` through a 3-2-1 `Task` (cancelled on the next
phase change) and only calls `resumeTimers()` once that reaches zero.
`Views/Puzzle/TimeTrialResumeOverlay.swift` renders the "Get Ready" dimming overlay + big
countdown number, shown whenever `session.isTimeTrialMode` (covers Gauntlet Ladder too) and
gated purely on `isShowingResumeCountdown`. Net effect: the countdown clock can no longer
resume ticking in the instant before the player has had a beat to reorient after any kind of
interruption, not just a full backgrounding.

**Limited Moves mode** (shipped June 2026): a flat per-grid-size move budget — every move
costs exactly 1 toward the budget, regardless of whether it locks a tile correctly (unlike
Time Trial, where correctness changes the time delta). `Models/GameModes/LimitedMovesRules.swift`
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
`Models/GameModes/ChaosTransform.swift` value — one `Orientation` pick (mirror/flip/rotate90/180/270),
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

**History calendar** (shipped 2026-07-06): a Locket-style month-grid of past completions
(`Views/Daily/DailyChallengeCalendarView` + `DailyMonthGridView` + `DailyDayCellView`, month
math in `Models/Calendar/DailyCalendarMonth`), reached by tapping the card body (the nested
Play button stays independent). `DailyChallengeStore.completedDayKeys: Set<Int>` (`yyyymmdd`)
persists which days are complete; `DailyChallengeStore.dayRecords: [Int: DailyDayRecord]`
(moves/time/streak, first completion per day wins) lets the calendar rebuild that day's
`ShareCardView` on demand and zoom it via the shared `ZoomedCardOverlay`. Completed cells are
tappable for a **Replay** (`GameSession.enterDailyMode(for:)` stores a transient
`dailyGameDate`; `recordCompletion(..., isPastReplay:)` skips streak/`lastCompletedDate` for
past replays but still lets global daily bests improve, and backfills a record for pre-
record-keeping days so a future tap shows the full card instead of the bare image).

**Daily reminder notification** (shipped 2026-07-12): `Services/DailyReminderService.swift`
wraps `UNUserNotificationCenter` with one pending notification at a time (id
`"dailyReminder"`). `rescheduleIfNeeded(enabled:time:completedToday:)` cancels and re-arms a
one-shot `UNCalendarNotificationTrigger` at a user-configurable hour/minute
(`SettingsView`'s toggle + `DatePicker`), rolling to tomorrow if today's puzzle is already
done or the time already passed; an 8-message pool rotates with no immediate repeat.
Rescheduled on daily completion and app foreground. The first-ever daily completion prompts
for notification permission and auto-enables the toggle if granted.

**Quick Snap** (shipped July 2026, mode-independence fix 2026-08-02): a new `.camera`
`MediaSourceType` rather than a new `GameMode` — it supplies only the image, never the
ruleset. Selecting it in `MediaSourcePickerView` (only offered when
`QuickSnapCameraSession.isCameraAvailable`) makes "Play" open a full-screen
`QuickSnapCameraView` instead of pushing the puzzle. That view wraps a `@MainActor @Observable`
`QuickSnapCameraSession` (an `AVCaptureSession`) bridged to SwiftUI through `CameraPreviewView`,
overlaid with a countdown ring that recolors under pressure like the streak timer. The whole
viewfinder is a tap-to-snap shutter (skips the countdown, Fitness-app style); otherwise the
frame is captured automatically at zero. Each second down fires a `.selection` haptic and the
capture a firmer `.impact`, both gated on `SettingsStore.hapticsEnabled`. The countdown length
is its own preference — `SettingsStore.quickSnapDuration` (3/5/10s via
`QuickSnapDurationPickerView`, read through `GameSession.currentQuickSnapDuration`) — no longer
piggybacking on `previewDuration`. On capture, `GameSession.enterQuickSnapMode(with:)` stores the
`CGImage` and flags `isQuickSnapActive` so `startNewGame()` slices it directly (bypassing
`ImageService`) and skips the "memorize the image" preview — `selectedGameMode` is left
untouched, so whatever mode the player already picked in `GameModeView` (Slide, Swap, Chaos,
etc.) still governs the engine, exactly like every other media source. **Fixed 2026-08-02:**
this method used to force `selectedGameMode = .swap` and save/restore the player's prior mode
around the Quick Snap session — a leftover simplification from when Quick Snap shipped as "just
a Swap puzzle with a camera photo" that silently discarded the player's actual mode choice (e.g.
picking Slide + Quick Snap played Swap instead). `activeEngine`'s dispatch on `selectedGameMode`
and every mode-specific branch in `startNewGame()` were already generic — the override in
`enterQuickSnapMode` was the only Quick-Snap-specific engine coupling in the codebase, so
removing it was the entire fix. Quick Snap now counts toward whichever mode's stats/streaks the
player selected, same as before but correctly attributed. "Play Again" from the completion
banner re-opens `QuickSnapCameraView` (presented by `PuzzleView` this time) so each round is a
fresh shot; `refreshQuickSnapImage(with:)` swaps in the new frame. `leaveGame()` clears the
Quick Snap flags; mode was never touched, so there's nothing to restore.

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

**Daily Challenge widget redesign + configurable photo** (2026-07-12): the widget
consolidated to one design (`NineTilesPuzzleWidgets/DailyChallenge/`): brand-gradient
wordmark header, hero grid-size/mode readout or a green "Solved" seal, a Duolingo-style
puzzle-piece streak row (weekday initials on medium), and on medium a "battery charge"
calendar-page date chip that visually drains through the day via 20%-step timeline entries.
`DailyChallengeConfigurationIntent` (a `WidgetConfigurationIntent`, edited through the
standard "Edit Widget" sheet) adds a "Show Puzzle Photo" toggle, off by default — when on,
`DailyChallengeProvider` fetches the day's seeded Picsum photo (the same URL formula as the
in-app puzzle) and masks it into the puzzle-piece watermark instead of the plain gradient.

**Live Activity resume deep link** (2026-07-16): `PuzzleLiveActivity`'s Lock Screen view and
Dynamic Island compact/expanded regions gained `.widgetURL(DeepLink.resume.url)`. Tapping the
Live Activity or Dynamic Island now resumes the in-progress game through the existing
`ninetilespuzzle://resume` route instead of just opening the app to the menu.

**Power-ups** (shipped 2026-07-07): five power-ups — Peek, Auto-place, Hint, Streak Freeze,
Re-shuffle (`Models/PowerUps/PowerUpType.swift`) — earned rather than bought and spent
mid-game. `PowerUpStore` (`@Observable`, `@MainActor`) is a `UserDefaults`-backed inventory:
`earn(_:amount:)`/`consume(_:) -> Bool`/`earnRandom()` (awards one random implemented type,
so growing the roster later needs no per-trigger redesign)/`resetToDefaults()`. Fresh installs
(and any power-up type added in a later update, detected via `object(forKey:)` returning
`nil`) start at `PowerUpRules.startingInventory` (3). Three earning triggers, all gated on
`SettingsStore.powerUpsEnabled` and skipped when `debugOverlayEnabled`, all in
`GameSession.registerMove()`: a streak crossing a milestone multiple of
`PowerUpRules.streakMilestoneInterval` (5, claimed once at solve time even if a puzzle's
moves cross several multiples), each achievement unlock (once per unlock in that move), and
Daily Challenge completion. **Challenge Friends completion does not earn a power-up** — see
below, flagged as an open question in `ROADMAP.md`. Each `use…PowerUp()` method in
`GameSession` (`usePeekPowerUp()`, `useAutoPlacePowerUp()`, `useHintPowerUp()`,
`useStreakFreezePowerUp()`, `useReshufflePowerUp()`) also gates on mode/media applicability
(e.g. Peek needs a reference image, so a Numbers-media game doesn't offer it) independently
of whether the type is owned, so an owned-but-inapplicable power-up's button stays visibly
disabled rather than doing nothing on tap. `PuzzlePowerUpToolbarView` hosts the five
`PowerUpBadgeButton`s in-game; `EarnedPowerUpBadgeView` plays a transient toast off
`PowerUpStore.recentlyEarned` (cleared at the start of each new game so the flourish never
replays against a stale award). `SettingsStore.debugInfinitePowerUps` bypasses `consume(_:)`
entirely for testing.

**Challenge Friends** (shipped 2026-07-08, extended through 2026-07-12): send a friend a
seeded puzzle and compare move counts/time — fully self-contained, no backend, superseding
an earlier iCloud+Game Center sketch. `FriendChallenge` (`Models/Challenge/`) is the
self-contained wire payload: sender name, mode, grid size, a freshly-minted seed, the
sender's own JPEG photo (`ChallengeImageCodec`), the sender's moves/time, a
`parentChallengeID` for "Challenge Them Back" chains, and a `formatVersion` for forward-
compat rejection. The receiver's device reproduces an identical board from the seed via
`Models/GameModes/SeededShuffle.swift` (extracted from `DailyChallengeSeeder` so both
features share the same seeded-derangement primitives) and shows a local win/lose/tie
comparison (`ChallengeStore.determineOutcome`) — zero server involvement, the same pattern
as Daily Challenge but with an arbitrary seed and the sender's real photo instead of a
reproducible remote URL. Sending needs no `GameSession` mode — it's a share action
(`ChallengeSendSheet`) off any finished, eligible game (every `GameMode` except `.zen`, which
tracks no move/time bests, and Gauntlet Ladder runs, which aren't a single reproducible
puzzle instance); only *receiving and playing* uses
`GameSession.enterChallengeMode(with:)`, the same transient-flag pattern as
`enterDailyMode`/`enterQuickSnapMode`. "Challenge Them Back" starts a fresh game in the same
mode/grid (needs a new image/seed, not the one just played) and auto-opens
`ChallengeSendSheet` once it solves.

Two transports share one payload. **File transport**: a custom `.ntpchallenge` UTType
(`cilia.filippo.NineTilesPuzzle.challenge`), `Transferable` via `FileRepresentation`, shared
through Messages/Mail/AirDrop/Files and opened via `MenuView`'s `.onOpenURL` →
`ChallengeFileOpeningModifier`. A `NineTilesPuzzleThumbnailExtension`
(`QLThumbnailProvider`, see directory layout above) renders a branded gradient-card preview
of the embedded photo (or an SF Symbol badge for an imageless `.result` reply) directly into
the QuickLook-provided `CGContext`, replacing the generic document icon Messages/Files/Finder
would otherwise show. `ChallengeFileCoder.decode` returns a
`Result<ChallengePayload, DecodeFailure>` (`.unreadable`/`.corrupted`/
`.unsupportedFormatVersion`, added 2026-07-10) rather than silently returning `nil`, so
`MenuView` can surface a "Couldn't Open Challenge" alert with a failure-specific message.
**Nearby transport**: `Services/ChallengeNearbySession.swift`, migrated 2026-07-09 from
Multipeer Connectivity to Network.framework — `NWListener`/`NWBrowser`/`NWConnection` over a
Bonjour `_ntp-challenge._tcp` service, peer-to-peer/AWDL enabled. Both a live automatic
result round-trip (the connection stays open after the challenge lands so the receiver's
`registerMove()` can fire a `ChallengeResult` straight back over the same socket, no second
handshake) and a manual file-based reply (`ChallengeResultSendSheet`, for when no live
channel exists) feed `ChallengeStore.recordOpponentResult(_:)`, which is idempotent — a
duplicate/re-delivered result can't clobber an outcome that's already recorded.

`ChallengeStore` (`@Observable`, `@MainActor`) persists history as UserDefaults JSON plus
on-disk JPEGs (`Documents/challenges/<id>.jpg`, 200-record cap); `AchievementCategory` gained
a `.social` case and `AchievementMetric` gained `.challengesSent`/`.challengesWon`/
`.challengesPlayed`, each reading live off `ChallengeStore`. Power-ups (above) can be *spent*
during a challenge game — nothing disables `consume(_:)` for `isChallengeGameActive` — but
none are *earned* from completing one, unlike Daily. **Not yet manually verified**: neither
transport has been tested end-to-end on two physical devices (Simulator can't do Bonjour
discovery or show real share-sheet destinations) — see `ROADMAP.md` §3.

**Gated behind Settings (2026-07-16):** pending that verification, the whole feature ships
hidden behind `SettingsStore.challengeFriendsEnabled` (off by default, toggled in Settings'
Dev Tools section — the same pattern as `powerUpsEnabled`): `MenuOptionsCardView` hides the
"Challenge Nearby Friends" row entirely when off; `PuzzleView.isChallengeEligible` additionally
requires the toggle before offering the send-a-challenge action on a finished game; and
`ChallengeFileOpeningModifier` checks it in `.onOpenURL` before decoding a tapped
`.ntpchallenge` file, showing a "Challenge Friends is Off" alert instead of silently opening it
(or silently no-opping) when disabled. The matching achievement gating is covered in the
Achievements section above.

**Monetization / Hard-Feature Gate** (shipped 2026-07-18, paywall UI rebuilt 2026-07-19): a
freemium split where Slide/Swap/Time Trial/Limited Moves/Zen stay free forever and the
highest-converting surfaces — Chaos/Haze game modes, personal-photo media sources (Photos/
Quick Snap/Mixed), Wall of Fame, the Achievements archive, the Daily Challenge calendar
archive, and system integration (Live Activities/Dynamic Island/Home Screen widgets) — are
gated behind a $6.99 lifetime non-consumable (`cilia.filippo.NineTilesPuzzle.lifetime`) or a
$1.99/mo auto-renewable subscription (`cilia.filippo.NineTilesPuzzle.monthly`, subscription
group "Premium Pass"). Shipped as a full gate in v1 (not staged) since the app was pre-launch
— no grandfathering logic exists or is needed.

`StoreManager` (`Models/Store/StoreManager.swift`, `@MainActor @Observable`) owns the
entitlement: loads both products via `Product.products(for:)` (retried up to 3× on a 500ms gap
if StoreKit's catalog returns a partial result right after a cold launch — a real race hit
during first manual testing), derives `hasActiveEntitlement` from `Transaction
.currentEntitlements` through the pure, StoreKit-free `StoreEntitlement
.isPremiumUnlocked(activeProductIDs:)` (unit-testable with no transaction plumbing), and
listens for `Transaction.updates` for out-of-band changes (Ask to Buy approval, renewal,
another device). `activeProductIDs` is retained (not thrown away after the scan) so
`hasActiveSubscription` can distinguish "active via the monthly subscription" from "active via
the lifetime non-consumable" — Settings only offers the native manage-subscription sheet in
the former case, since a lifetime purchaser has nothing to manage. A `.pending` purchase
result (Ask to Buy, SCA/bank approval) sets `pendingApprovalMessage`, shown as neutral inline
copy on the paywall instead of the purchase silently doing nothing. `isPremiumUnlocked` also
ORs in a `debugOverride` closure so Settings' Dev Tools "Force VIP Unlocked" toggle can
simulate premium without a sandbox purchase, and ANDs in the negation of a `debugForceRemoved`
closure so the Dev Tools "Remove VIP Lifetime Access" button can suppress a real (or forced)
entitlement — removal wins over both — to test the non-VIP experience without deleting the
transaction in Xcode's StoreKit Transaction Manager. Both mirror `GameSession`'s injected
`isPremiumUnlocked` closure pattern below. The entitlement is mirrored into the shared App
Group via `WidgetDataController.updateEntitlement` (not written directly — that controller
owns every App Group write + the paired `WidgetCenter` reload) so the widget extension, which
never links StoreKit, can read it without a round trip through the app.

`PremiumFeature` (`Models/Store/PremiumFeature.swift`) plus `GameMode.isFree`/
`MediaSourceType.isFree` are the pure, StoreKit-free gating rules, fully unit tested.
`GameSession` takes an injected `isPremiumUnlocked: () -> Bool` closure (default `{ true }`, so
none of the existing test files or `#Preview` blocks needed touching) as a belt-and-suspenders
guard in `setGameMode`/`setMediaSourceType`; `LiveActivityController` takes the same closure
pattern to gate `start`/`refresh` (never `end`, so an already-running Live Activity for a
formerly-premium player who un-subscribes still ends cleanly). **Critical invariant — do not
break:** `DailyChallengeSeeder.availableGameModes = [.slide, .swap, .limitedMoves]` assigns
premium modes to the free Daily Challenge; the gate is bypassed entirely for `enterDailyMode()`,
which assigns `selectedGameMode` directly rather than through the guarded setters. (Quick Snap
no longer needs this carve-out as of the 2026-08-02 fix described in the Quick Snap section
above — `enterQuickSnapMode(with:)` doesn't touch `selectedGameMode` at all anymore, so a free
player's mode there is whatever they already legitimately have access to.)

`PaywallView` + `PaywallContext` (`Views/Paywall/`) is the contextual sheet, presented
everywhere via the `.paywallSheet(context:)` view modifier — one `PaywallContext` case per
trigger (a specific `GameMode`, a `MediaSourceType`, Wall of Fame, Achievements, the Daily
archive, system integration, or `.general` from Settings) drives the headline/subheadline/icon
so the sheet reads as contextual rather than one generic upsell. Guideline 3.1.2 compliance —
`PaywallLegalLinks.swift` (Terms of Use: Apple's Standard EULA; Privacy Policy: the real
GitHub Pages URL) plus the auto-renewal disclosure text — are both always on screen, since the
monthly subscription is always one of the two offered plans.

**Paywall rebuilt around StoreKit 2 depth, not just visuals (2026-07-19):** the original
paywall paired two independent buy buttons with a "monthly is a decoy" framing (`PaywallProductButton`,
now removed). Rebuilt as selectable plan cards confirmed by one CTA — the user chose this over
keeping the decoy layout, and explicitly declined adding a free trial/introductory offer this
round since that needs a real ASC-side offer configured first, not just a local `.storekit`
change. `PaywallPlanCard.swift` renders each plan as a tappable row — a green radio checkmark
(only the newly-selected card's icon plays `.symbolEffect(.bounce)`, gated on a counter that
increments solely on its own false→true transition, so the sibling card losing selection stays
still) and a green-tinted Liquid Glass background via `.glassEffect(...tint...)` when selected.
`PaywallPlanListView.swift` owns the plan list — a `.redacted(reason: .placeholder)` skeleton
while `StoreManager.isLoadingProducts`, a retry button if loading came back empty, or the two
real cards once StoreKit has them — and shows the lifetime card's "BEST VALUE" badge only once
`lifetimeIsBestValue` confirms both real `Product.price` values loaded and the lifetime price
is nonzero and cheaper than paying monthly indefinitely, rather than showing it unconditionally.
`PaywallCTAButton.swift` is the single `.buttonStyle(.glassProminent)` confirm button — its
title tracking whichever plan `PaywallView`'s `selectedProductID` currently points at (defaults
to lifetime once products load, matching the old default-emphasized option), crossfading via
`.contentTransition(.opacity)` instead of snapping instantly when the selection changes. Whole
app targets iOS 26.2 (confirmed via `IPHONEOS_DEPLOYMENT_TARGET`), so no `#available` gating was
needed for `glassEffect`/`GlassEffectContainer`/`.buttonStyle(.glassProminent)`. Same session:
`SettingsView` gained a "Manage Subscription" row (shown only when
`store.hasActiveSubscription`) wired to the native `.manageSubscriptionsSheet(isPresented:)` —
didn't exist before.

**Not yet done:** no manual purchase/restore verification on a real device or two-device
setup; the App Store Connect review screenshots already uploaded for both the lifetime IAP and
the monthly subscription were captured against the *old* dual-button paywall and are stale
against this rebuild — should be recaptured before submitting. See `ROADMAP.md` §4 and this
project's memory for the full ASC submission trail.

**Billboard cross-promo ads / "Remove Ads" perk (shipped 2026-08-02):** the app's first
third-party dependency, [Billboard](https://github.com/hiddevdploeg/Billboard) (SPM, MIT), a
free indie cross-promotion network — it shows a full-screen promo for another indie app (never
this app's own, see below) and generates no ad revenue itself; the value is entirely the
existing Hard-Feature Gate entitlement removing it, not a new revenue stream. Deliberately
bundled into the existing Lifetime/Monthly entitlement rather than a separate SKU — no new
`PremiumFeature` case was needed, the gate is just `!store.isPremiumUnlocked` at the call site.

Placement is the single hardest part of doing this without being obnoxious: `GameSession` gained
`completedGameLeaveSignal: Int`, bumped only by `PuzzleView`'s `.onDisappear` when
`session.isSolved` is true at that moment — so it fires once per solved game, right as the
player leaves the puzzle screen, and specifically not on a mid-game quit (blocked upstream by
`isGameActive`/`showQuitAlert` gating the quit path to unsolved games only) and not during
"Challenge Them Back" (`challengeThemBack()` calls `session.leaveGame()` but never dismisses
`PuzzleView`, so `onDisappear` never fires there). `MenuView` — the stable `NavigationStack`
root that `PuzzleView` pops back to — observes the signal via `.onChange` and presents the ad
through Billboard's own `.showBillboard(when:)` modifier, gated on `!store.isPremiumUnlocked`.
`BillboardConfiguration(excludedIDs: ["6776386637"])` excludes this app's own Apple ID (the ASC
app resource id, same number as the App Store URL) so Billboard never advertises this app to its
own free players — relevant since the app is being submitted to Billboard's own directory
separately. Tapping "Remove Ads" inside the ad overlay shows the existing `PaywallView` with a
new `.removeAds` `PaywallContext`; the benefit carousel (`PaywallBenefit.swift`) that every
paywall view already shows also gained a "Play Uninterrupted" card, so the perk is visible
even to players who reach the paywall from an unrelated locked feature.

**Not yet done:** the Lifetime/Monthly price bump discussed alongside this feature (to reflect
the added perk) hasn't been applied in App Store Connect — that's a live pricing change on
existing products, left for an explicit follow-up rather than done as a side effect of the code
change. No on-device/simulator visual verification of the ad flow yet either (build- and
test-verified only, per this project's "no `axe` without permission" convention).

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

**Manual curation + share-button relocation (shipped 2026-07-16):** `WallOfFameStore` gained
two persisted, purely-display preferences that never touch the underlying personal-best
records: `hiddenFileNames: Set<String>` (`isHidden(_:)`/`setHidden(_:hidden:)`, JSON under
`wallOfFame.hiddenSlots`) and `sectionOrder: [String: [String]]` (a section identifier like
`"bestMoves"` → `fileName`s in display order, JSON under `wallOfFame.sectionOrder`).
`orderedSlots(section:canonical:)` reorders a section's canonical slot list per any manual
arrangement, falling back to canonical order for a slot never touched (never moved, or added
in a later update); `move(_:section:canonical:earlier:)` swaps a slot with its immediate
neighbor in that resolved order and persists the result. `WallOfFameView.curatedCardSlot(for:
section:canonical:)` wraps every per-slot record section (not the derived "Difficulty
Highlights" hero cards, which have no single stable slot identity to hide or reorder) with a
`.contextMenu` (long-press): an earned, visible card offers "Unpin from Wall" (destructive) and
`moveMenuButtons` ("Move Earlier"/"Move Later", each hidden at its respective end of the
section); a hidden slot renders as `WallOfFameEmptySlot` with only "Re-pin to Wall"; a
never-earned slot renders exactly as it always did, with no menu, since there's nothing yet to
unpin or move. Separately, the zoomed overlay's Share button moved off the nav bar
`ToolbarItem` into `ZoomedCardOverlay`'s existing generic `Footer` slot (added alongside the
Daily Challenge calendar's Replay button) as a `.borderedProminent` `ShareLink`, so sharing now
happens from the card itself rather than the surrounding chrome.

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
ever actually being wired up or compiled). 281 `@Test` functions currently pass (up from 169
at the widget work below — Challenge Friends and Power-ups each added their own suites, see
end of this section), covering: both engines
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

Challenge Friends added `ChallengeStoreTests`, `ChallengeImageCodecTests`, and
`GameSessionChallengeTests` (the full receive → play → complete → outcome integration
against a real `GameSession`); Power-ups added `PowerUpStoreTests` and
`GameSessionPowerUpApplicabilityTests` (per-mode/media gating of each `use…PowerUp()` method,
independent of whether the type is actually owned). Wiring Challenge Friends up from the CLI
also required adding a `<Testables>` block to the shared `.xcscheme` — it only had
`shouldAutocreateTestPlan = "YES"` with no explicit `TestableReference`, which works silently
in Xcode's GUI but makes `xcodebuild test` fail with "Scheme ... is not currently configured
for the test action."
