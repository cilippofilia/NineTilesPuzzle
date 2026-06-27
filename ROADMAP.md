# NineTilesPuzzle — Improvement Roadmap

Each idea has an effort estimate — **S** (hours), **M** (days), **L** (a week or more) — and
notes on how it hooks into the existing architecture.

---

## 1. New Game Modes

All modes reuse the stateless `GameEngine` conformers (`ClassicEngine`/`SlideEngine`) and
route through `GameSession`. The natural starting point is the existing `GameMode` enum
already threaded through `GameSession`, with mode selection routed via the existing
`GameRoute` enum in `Views/MenuView.swift`. See `ARCHITECTURE.md` for how `GameSession`,
`StatsStore`, `SettingsStore`, and `AchievementsStore` fit together today.

[X] ### Daily Challenge — **M** *(shipped June 2026)*
One puzzle per day, identical for every player. A date-seeded picsum URL
(`/seed/ntp-YYYY-MM-DD/1024/1024`) delivers the same image to every device; a seeded
xorshift64 PRNG (`DailyChallengeSeeder`) produces the same derangement shuffle from the same
date integer. `DailyChallengeStore` tracks a calendar streak of completed days (separate from
the in-game move streak), all-time best calendar streak, and daily personal bests for moves
and time. `DailyImageSource` fetches via the system URL cache (unlike `RemoteImageSource`
which bypasses caching), so the image is loaded at most once per day. On the menu a dedicated
`DailyChallengeCardView` shows today's date, the current streak, and a "Play" button that
transitions to "Done ✓" once completed; the Play button calls `session.enterDailyMode()`
which sets a transient `isDailyGameActive` flag — the session routes the seeded image fetch
and shuffle through `startNewGame()`, skips the regular move-streak countdown, and on solve
routes to `DailyChallengeStore.recordCompletion()` rather than StatsStore. The flag is reset
in `leaveGame()` so the user's regular mode preference is untouched after playing a daily.
Still deferred:
- Leaderboard for daily challenge (§3 prerequisite for comparison across players).
- Calendar streak achievements (7 / 30 days) — deferred until §5 achievements overhaul.
- Replay limit / "come back tomorrow" gate — today the player can replay the same puzzle to
  improve best moves/time; the calendar streak only advances once per day.

[X] ### Time Attack — **S/M**
Shipped as Time Trial mode (MVP scope, June 2026): one timed puzzle per grid size, with a
flat combo bonus/misplay penalty per move and a simplified score formula. Reused the streak
countdown timer's `Task`-based shape in `GameSession` almost exactly, generalized from "time
per correct move" to "time per puzzle" — see `ARCHITECTURE.md` for the implementation.

The full 10-stage **Gauntlet Ladder** progression also shipped (June 2026), as a toggle
inside Time Trial rather than a new mode — see `ARCHITECTURE.md` for the implementation.
Time limits were nerfed in June 2026 (roughly +20–35% across all stages, scaling more
generously for larger grids) after playtesting showed completion was too difficult.
Still deferred to follow-up work, from the original feature spec:
- The Endless "Ghost Mode" (stage 11+), racing the player's own personal best pace.
- Time-banking: carrying over a percentage of leftover time between ladder stages.
- The low-time vignette pulse and BPM-escalating audio sensory layer (the countdown
  currently only recolors text, per the existing `StreakCounterView`-style pattern).
- Restricting Time Trial to a curated, high-contrast image source for leaderboard fairness.
- `scenePhase`-based countdown freeze + 3-2-1 resume overlay on backgrounding/interruption
  (today the countdown has no background handling at all, same as the streak countdown).

[X] ### Limited Moves — **S**
Shipped June 2026: a flat per-grid-size move budget (`Models/LimitedMovesRules.swift`,
3×3 → 12 moves up to 115 for 8×8+), reusing the existing move counter and adding a budget
check + fail state (`LimitedMovesFailView`'s "Out of Moves" overlay) — see
`ARCHITECTURE.md` for the implementation. Still pairs naturally with the power-up economy
(§2), and the move-budget table could use difficulty-based tuning passes later if playtesting
shows the flat numbers are too generous/strict.

[X] ### Zen Mode — **S**
No timers, no streak pressure, no fail states — just the picture. Cheapest mode to build
because it *disables* existing systems rather than adding new ones. Good for the audience
that plays with personal photos.

[X] ### Classic Slide (15-puzzle variant) — **M/L**
One empty cell, tiles slide instead of swap. Needs new engine rules (legal-move adjacency
and a solvability parity check on shuffle — half of random permutations are unsolvable) but
reuses the entire image-slicing and grid-rendering pipeline. Effectively a second game in
the same app.

[X] ### Haze — **M** *(shipped as "Haze", case `.fog` in `GameMode`)*
Shipped June 2026. Tiles start hidden behind an animated sparkle overlay (`FogTileOverlay`,
a `Canvas`+`TimelineView` particle system seeded per tile so each tile's star field is
unique). Three tile states driven purely by `TileModel` fields and local `isDragging`:

- **Fogged** (unlocked, not dragging): heavy blur (18pt) + dark overlay + twinkling particles.
- **Frosted glass** (dragging): lighter blur (3pt), no particles — you can see what you're
  placing but just barely.
- **Revealed** (locked/correct): full-color image, slow 1.2s easeInOut fade from fog.

A dedicated preview phase (duration matches `settingsStore.previewDuration`) shows the image
fogged by default; a `ShakeDetector` (UIKit bridge in `Views/Helpers/`) lets the player shake
to lift the fog before tiles shuffle. The shake hint badge uses `LoudBounceModifier` (scale
pop, brightness flash, horizontal rattle — iMessage Loud+Shake style). The fog overlay and
shake gesture are gated on `isFogMode` inside `ImagePreviewView` so other modes see a plain
"Memorize the image" preview with no fog. Still visual-twist, not budget-based — runs on
`ClassicEngine` (SwapEngine) and feeds the same completion/streak/personal-best path as Swap.
No new `GameEngine`, no fail state.

[X] ### Chaos Mode — **S**
Shipped June 2026, as a whole-image transform rather than the originally-sketched per-tile
flags: a random `ChaosTransform` (one orientation pick — mirror/flip/rotate90/180/270 — plus
one tone pick — desaturate/invert/hue-shift/sepia — plus independent posterize and pixelate
coin flips) is baked into the source image once at shuffle time, before `ImageSlicer` ever
sees it, so every tile inherits the same transform and the solved puzzle still reads as one
coherent (if mirrored/inverted/pixelated) photo. The puzzle's correctness stays purely about
grid position — see `ARCHITECTURE.md` for why this needed a dedicated `previewImage` so the
pre-shuffle "memorize the image" step still shows the real photo, not the chaos version. No
new `GameEngine`, no new fail state, no stats/streak exemption (it plays exactly like Swap
underneath). Same pattern still available for a future Fog/Reveal: this shipped as a
whole-image bake rather than per-tile `TileModel` flags, so Fog/Reveal would need its own
approach if it wants tile-level reveal timing rather than a single baked-in effect.

### Gravity Mode — **M**
A tilt-to-play mode: the player holds their phone and all tiles simultaneously slide toward
the direction of gravity. Tilt left → every tile drifts left until it hits the wall or
another tile; tilt right → same in reverse; and so on for up/down. The mechanic is
fundamentally different from Slide (where you drag one tile into the adjacent blank cell)
because every tile moves at once — the empty space(s) collect at the "high" side of the
board, and the order in which you make moves matters at a whole-board level.

Architecture hooks:
- Add `.gravity` to the `GameMode` enum and a `GravityEngine: GameEngine` in `Services/`.
  `shuffle()` can delegate to `SwapEngine`'s derangement shuffle since any state is
  solvable under gravity rules (no parity constraint). The engine exposes a
  `slide(direction:)` method that iterates columns/rows and cascades tiles toward the wall.
- `GameSession` gets a `gravitateBoard(direction: GravityDirection)` entry point (analogous
  to `slideTile(from:)`) that calls the engine and then `registerMove()`.
- Motion input via a `MotionManager` service (`@Observable @MainActor` wrapping
  `CMMotionManager.startDeviceMotionUpdates`). Gravity vector from `CMDeviceMotion.gravity`
  maps to a discrete direction once a tilt threshold is crossed; a cooldown prevents
  repeated triggers on a single deliberate tilt.
- `PuzzleGridView` embeds a tilt listener (similar to the existing `ShakeDetector` pattern
  in `Views/Helpers/`) that calls `session.gravitateBoard(direction:)` on threshold
  crossings. Drag gestures can be disabled entirely for this mode.
- A tilt-direction indicator (arrow or subtle board-edge highlight) gives the player
  real-time feedback on which way the tiles will slide.

Still to decide: whether to use a discrete threshold (snap to the dominant axis) or a
continuous tilt that lets tiles slide diagonally. Discrete is simpler to implement and
likely more fun to play.

### Quick Snap — **S/M**
Point the camera at whatever's in front of you right now and the shutter fires on a
countdown — no retakes, no framing it just right. Whatever the camera sees when the timer
hits zero becomes the puzzle. Not a new engine or rule set: it plays exactly like Swap
underneath (same pattern as Chaos/Haze), the only new thing is *where the image comes from*
and the pressure of "this very second" replacing "pick something."

The shot timer is `max(settingsStore.previewDuration, 3)` seconds — it rides the same
preview-duration setting used for "memorize the image" (default 3s already satisfies the
floor), but never drops below 3s even if the player has set previews to "Off" (0) or
something shorter, since under 3s there isn't enough time to aim the camera at all. Once the
timer hits zero the frame is captured automatically; there is no shutter button and no retake
— committing to whatever's in frame is the point of the mode.

Architecture hooks:
- The existing `ImageSource` protocol's `fetchImage() async throws -> CGImage` assumes a
  headless fetch (network call, photo library query). Camera capture needs a presented UI
  step first, so it doesn't fit as a drop-in fourth conformer the way `PhotoLibraryImageSource`
  does — instead, add a live camera preview (`AVCaptureSession` wrapped in a
  `UIViewControllerRepresentable`, since `UIImagePickerController` has no way to suppress its
  own shutter button/retake screen) with a countdown ring overlay; on zero it grabs the
  current frame as a `CGImage` and hands it to `GameSession` directly, bypassing
  `ImageService`'s primary/fallback source pair entirely for this one mode.
- `GameSession.enterQuickSnapMode()` (mirrors `enterDailyMode()`'s transient-flag pattern)
  presents the camera sheet with the countdown already running; auto-capture at zero calls
  `startNewGame()` with that frame, then resets the flag in `leaveGame()` like Daily
  Challenge does.
- The countdown overlay reuses the existing countdown visual language (the streak/Time Trial
  countdown's text recoloring under pressure) rather than introducing a new timer style.
- Skips `ImagePreviewView`'s "memorize the image" step entirely — the player just watched the
  scene through the countdown, so a second memorize phase would be redundant; shuffle starts
  immediately after capture.
- Needs a new `NSCameraUsageDescription` entry in `Info.plist` — today only
  `NSPhotoLibraryUsageDescription` exists. Camera access can be denied or the device may have
  no camera (Simulator); fall back to `ImageSourceError`-style messaging and grey the mode out
  in the menu the same way `.numbers` is only shown conditionally in `MediaSourcePickerView`.
- Runs on `ClassicEngine` (Swap) — no new `GameMode` rules, no fail state, no stats/streak
  exemption.

---

## 2. Power-ups & Twists

Earned rather than bought (at least initially): award them at streak milestones, achievement
unlocks, and daily-challenge completions. Inventory is a handful of counters persisted
alongside the existing per-store `Keys` enums (each store now sits behind the
`PersistenceStore` protocol, so a power-up counter store is straightforward to keep
testable too). Each one is small because the mechanics it manipulates already exist:

| Power-up | Effort | How it works |
|---|---|---|
| **Peek** | S | Re-show the full image mid-game for a few seconds — `ImagePreviewView` already does this pre-shuffle. |
| **Hint** | S | Briefly highlight where one selected tile belongs. |
| **Auto-place** | S | Lock one random unlocked tile into its correct cell via the existing swap/lock logic. |
| **Streak Freeze** | S | Pause the streak countdown once per game. |
| **Re-shuffle** | S | Reshuffle only the unlocked tiles (a constrained `GameEngine.shuffle`) when stuck. |

**Economy note:** milestone-based earning keeps the game fully offline-friendly and
pressure-free. If monetization ever lands (§4), power-up bundles become an obvious IAP
without redesigning anything.

---

## 3. Game Center / Online

The biggest new capability, and the cheapest path to "online": GameKit needs no custom
backend. Prerequisite is Game Center configuration in App Store Connect (leaderboard and
achievement IDs).

### Leaderboards — **M**
The stats are already tracked in `StatsStore`; submission is a thin `GameCenterService`:
- Best moves per difficulty (six leaderboards, one per grid size)
- All-time best streak
- Daily challenge: recurring leaderboard for moves (and time, once Time Attack exists)

### Achievements sync — **M**
Mirror the 10 local achievements (`Resources/achievements.json`) to Game Center, reporting
on unlock. Keep the local system as the source of truth so the game still works fully
offline. While in this area: `AchievementService.remoteURL` still points at
`example.com` — either wire up a real hosted JSON or remove the remote path.

### [X] Access point — **S** *(shipped June 2026)*
A `gamecontroller` toolbar button on the menu screen (visible only when authenticated) opens
the native Game Center dashboard via `GKAccessPoint.trigger(handler:)` — the iOS 26
replacement for the deprecated `GKGameCenterViewController`. The access point widget itself
(`GKAccessPoint.isActive`) is kept inactive so the system-provided icon never appears;
authentication is handled by `GameCenterService` (injected app-wide) at startup.
Prerequisite: Game Center capability must be enabled under Signing & Capabilities.

### Friend challenges — **L** *(defer)*
Send a friend the same seeded puzzle and compare move counts. Builds directly on the
Daily Challenge seeding work, but should wait until leaderboards prove engagement.

---

## 4. Progression & Polish

### XP / player level — **M**
XP per solve, scaled by grid size and efficiency; level badge on the menu. Gives every game
a reward even when no record is broken, and provides a gate for unlocking cosmetics and
image packs.

### Image packs & themes — **M**
Curated bundled packs (nature, art, architecture, space) as a third source alongside
picsum and the photo library — slots cleanly into the existing `ImageSource` protocol.
App-wide accent themes ride along. Later: premium packs as IAP.

### AI-generated puzzle images (Image Playground) — **M**
An "AI Images" source next to Internet and Photos: use the `ImageCreator` API
(ImagePlayground framework, programmatic, no UI) to generate a random illustration from a
rotating pool of concepts and slice it into tiles. Slots straight into the existing
`ImageSource` protocol as a fourth conformer. Requires Apple Intelligence-capable hardware —
check availability and hide the option (or fall back to remote) on unsupported devices.
Works fully offline once the model is on device, and every puzzle is one-of-a-kind.

### Stats history & charts — **M**
Persist a per-game record (date, difficulty, moves, duration, mode) instead of only
aggregates. This is the natural point to introduce **SwiftData**; render trends with
**Swift Charts** in an expanded `StatsView`.

### iCloud sync — **M**
`NSUbiquitousKeyValueStore` is a near-drop-in for the current UserDefaults stats and
achievement flags. If SwiftData lands for stats history, CloudKit-backed sync becomes the
fuller option.

### Widgets — **M**
A daily-challenge widget ("Today's puzzle awaits" → completed state) and a streak widget.
Requires a widget extension and an App Group to share state.

### Monetization *(optional, later)* — **L**
Lightest-touch options first: tip jar, then premium image packs and power-up bundles via
StoreKit 2. Nothing in the current architecture blocks this; the power-up economy and image
packs are designed to make it bolt-on.

### Smaller polish — **S each**
- [X] Pause timers when the app is backgrounded — `PuzzleView` monitors `scenePhase` and
  calls `session.pauseTimers()` / `session.resumeTimers()` (shipped June 2026).
- [X] Share a completed puzzle as an image via `ShareLink` — toolbar share button appears in
  `PuzzleView` once the puzzle is solved; exports a PNG of the completed image via a custom
  `Transferable` type and `SharePreview` (required in iOS 26). *(shipped June 2026)*
- [ ] Accessibility audit — drag-to-swap needs a VoiceOver-friendly alternative (e.g.
  select-then-place via accessibility actions).

[X] ### Wall of Fame — **M** *(shipped June 2026)*
A cork-board view where every personal record is automatically pinned as a polaroid card.
15 slots in four sections, defined by `Models/WallOfFameSlot.swift`:
`bestMoves(gridSize: 3…8)`, `bestTime(gridSize: 3…8)`, `dailyBestMoves`, `dailyBestTime`,
`calendarStreak`. At the moment any record is set `PuzzleView` renders `ShareCardView` via
`ImageRenderer` at scale 3, converts the result to a `CGImage`, and calls
`WallOfFameStore.save(_:for:)` — which writes a PNG to
`Documents/wall_of_fame/<slot>.png` using ImageIO (no UIKit) and caches the `CGImage`
in memory. Cards are auto-pinned; no manual curation.

Visual design:
- `WallOfFamePinnedCard`: 160 × 192 pt image, clipped at 3pt corner radius,
  seeded base rotation ±6° (derived from `slot.seedValue × 1_000_003 % 13`),
  📍 emoji pin at top edge, shadow offset tracks live swing angle.
- **Pendulum physics**: `TimelineView(.animation(minimumInterval: 1/60))` drives a
  spring-damper loop — `angularVelocity += (target − angle) × stiffness + −velocity × damping`
  — at 60 fps. `MotionManager.roll` sets the equilibrium angle; stiffness = 0.025,
  damping = 0.11 gives the lazy, heavy swing of a real card on a pin.
- **Gyroscope**: `Services/MotionManager.swift` wraps `CMMotionManager.startDeviceMotionUpdates`
  at 30 Hz. The first attitude reading is captured as a reference
  (`CMAttitude.multiply(byInverseOf:)`), so cards hang vertically regardless of how the
  phone is held when the view opens. Roll is clamped to ±0.14 rad and normalized to −1…1.
- **Cork texture**: `CorkTextureView` is a multi-layer `Canvas` drawing using a seeded LCG
  PRNG (`SeededRNG`) for per-pixel noise — ochre base, diagonal grain streaks, scattered
  darker specks — no bundled asset, renders once and never redraws.
- **Empty slots**: dashed rounded-rect outline (`WallOfFameEmptySlot`) so the board reads
  as something to fill in.
- **Tap to zoom**: tapping a pinned card sets `zoomedSlot`/`zoomedCardImage` state in the
  root `ZStack`. The dark backdrop and card content are sibling views so each can carry
  its own transition — backdrop fades (`.opacity`), card scales + fades
  (`.scale(0.82).combined(.opacity)`) — both driven by a single
  `.animation(.spring(response: 0.38, dampingFraction: 0.85), value: zoomedCardImage == nil)`.
  A transparent `Color.clear.contentShape(.rect)` dismiss button avoids the button-press
  color flash that a tinted label would cause.
- **Share from zoom**: a `ShareLink` `ToolbarItem` appears in the nav bar when a card is
  zoomed, referencing the on-disk PNG URL from `WallOfFameStore.fileURL(for:)`.

Stats moved from `MenuView` sheet to `SettingsView` push-navigation (June 2026). Stats
button removed from the menu; `StatsView` is now a plain `List` (no `NavigationStack` of
its own) pushed via `NavigationLink` from inside `SettingsView`'s `NavigationStack`.

Still deferred:
- Manual curation (long-press to unpin / rearrange slots).
- Tapping a card's share button from the zoomed overlay (currently only the nav bar item).

### [X] Menu stats card — **S** *(shipped June 2026 as `MenuStatsCardView`)*
Re-added with per-mode content: three-stat card (streak / best streak / best moves) for
Swap/Slide/Haze/Chaos; two-stat card (best score / best moves) for Time Trial; two-stat card
(best moves / best time) for Limited Moves; two-stat card (best score / best stage) for
Gauntlet Ladder; hidden entirely for Zen. Lives in `Views/Streak/MenuStatsCardView.swift`.

---

## 5. Achievements Overhaul

Take inspiration from Apple Fitness awards: badges grouped by category, tiered medals with
progress shown toward the next tier, earned dates, and occasional limited-edition awards.
Today the system is 10 flat achievements with a binary `isUnlocked` flag and a hardcoded
`switch` in `AchievementsStore.checkAchievements(using:)` — most of this section starts
with making definitions data-driven.

### [X] Data-driven model with progress — **M** *(foundation for everything below)*
`Achievement` now carries `category: AchievementCategory`, `metric: AchievementMetric`,
`target: Int`, `comparison: AchievementComparison`, and `unlockedDate: Date?`. The old
hardcoded `switch` in `checkAchievements` is gone — the generic loop evaluates
`metric.value(in: stats) comparison target` for every entry. `achievements.json` drives all
34 achievements across 6 categories; existing UserDefaults keys are unchanged (no migration
needed). `AchievementMetric` encodes as a dotted string (e.g. `personalBestMoves.3.swap`)
so the JSON stays hand-editable. `AchievementComparison` is `greaterThanOrEqual` or
`lessThanOrEqual` — move-count efficiency achievements use the latter.

### [X] Categories — **S** *(after the model work)*
Group `AchievementsView` into sections, Fitness-style:

| Category | What lives there |
|---|---|
| **Milestones** | First Solve, total puzzles completed |
| **Difficulty** | First clear of each grid size (3×3 → 8×8 — add the missing 6×6 and 7×7) |
| **Efficiency** | Move-count records per grid size |
| **Streaks** | Move-streak tiers, perfect games |
| **Explorer** | Image sources, modes, variety play |
| **Special** | Hidden + limited-edition awards |

### Tiered achievements (bronze / silver / gold) — **M**
Collapse "count ladder" achievements into one badge with tiers, like Fitness's Move Goal
awards. A tier is just an array of targets in the JSON; the badge renders in the tier color
of the highest level reached:

- **Solver**: 10 / 50 / 200 puzzles (absorbs today's `tenGames` and `fiftyGames`)
- **Streak**: 10 / 25 / 50 (absorbs `streak10` and `streak25`)
- **Grid Master**: complete every grid size once / 5× each / 25× each
- **Efficient**: beat the par move count on 1 / 3 / all 6 grid sizes

Optionally a platinum tier as the long-tail goal. The toast (`AchievementToastView`) shows
which tier was just reached. If Game Center sync (§3) lands, each tier maps to its own GC
achievement, or to one achievement using `percentComplete`.

### [X] Progress bars — **S** *(falls out of the data-driven model)*
Show progress toward the next locked tier wherever an achievement appears:
`AchievementRowView` gets a `ProgressView(value:)` or circular `Gauge` ("37/50 puzzles"),
and locked badges render greyed-out with the bar underneath — exactly how Fitness shows
unearned awards. One-shot achievements (e.g. "solve an 8×8") stay binary, no bar.

### [X] New achievements — **S each** *(once the model is data-driven, these are JSON entries)*
All roadmap achievements shipped as JSON entries (June 2026): Perfectionist, Marathon,
Night Owl, Early Bird, Personal Touch, Comeback, Full House, plus Zen/Time Trial/Limited
Moves/Haze/Chaos/Ladder first-clears. Still deferred:
- **Sharpshooter** (beat personal best 3× on same grid size) — needs a new `StatsStore`
  counter; deferred until §3 leaderboard work makes per-grid-size tracking richer.
- Daily-challenge calendar streaks (7 / 30 days) — blocked on §1 Daily Challenge.

### Fitness-style extras — **M** *(later, once the above ships)*
- **Limited-edition awards**: seasonal badges (New Year solve, app anniversary) — this is
  the actual payoff of the existing remote-fetch infrastructure in `AchievementService`,
  since limited editions can be pushed without an app update.
- **Monthly challenge**: one personalized goal per month computed from the player's own
  stats ("Solve 20 puzzles in June"), shown as a card with a progress ring on the menu.
- **Badge detail sheet**: tapping a badge opens a large rendering with earned date, tier
  history, and a share button (`ImageRenderer`, pairs with the share polish item in §4).
- **Generated commemorative badges (Image Playground)**: for gold-tier unlocks and monthly
  challenge completions, generate a one-of-a-kind celebratory image via the `ImageCreator`
  API (e.g. "golden trophy made of puzzle pieces") in the background at unlock time, persist
  it, and show it in the badge detail sheet alongside the canonical badge. The SF Symbol +
  tier-color badge stays the source of truth: generation needs Apple Intelligence-capable
  hardware, takes a few seconds, has no style consistency, and can fail — so it's an
  enhancement layer, never the only artwork.

---

## 6. Architecture Notes

Current structure (directory layout, store boundaries, persistence, testing) is documented
in `ARCHITECTURE.md`, not duplicated here — that file is the single source of truth so the
two docs don't drift out of sync with each other again.

**Open question, revisited with Time Trial and Limited Moves both shipped (June 2026):**
`GameMode` is 7 cases, and mode-specific behavior (`isZenMode`, `isTimeTrialMode`,
`isLimitedMovesMode`, `selectedGameMode == .slide`, debug-overlay gating) is still scattered
conditionals inside `GameSession` and `PuzzleView`/`PuzzleGridView` rather than a single
abstraction. A small composable `GameModeRules` was considered a third time now that Limited
Moves exists — the predicted pairing happened (Time Trial and Limited Moves do share a real
"budget + fail condition, checked after the solved branch" axis, unlike Zen, which only
disables tracking) — but conditionals won again, more narrowly: the two budgets differ
enough in kind (mutable wall-clock time with a combo score vs. a flat decrementing move
count with no score) that a shared struct would carry fields meaningless to one conformer or
the other, for a payoff of collapsing two small `if`/`else if` branches. See
`ARCHITECTURE.md`'s §6 resolution for the full reasoning. The Gauntlet Ladder still doesn't
add a data point here — it's deliberately modeled as a boolean flag on top of Time Trial
(`isLadderMode`), not a new `GameMode`. Chaos Mode shipped since (June 2026) but doesn't add
a data point either — it's a visual-only whole-image transform with no budget or fail state,
playing like Swap underneath. Revisit the `GameModeRules` question again if a third
budget-based mode arrives. Fog/Reveal also shipped June 2026 (also visual-twist, not
budget-shaped) — all planned modes are now live; that third budget-based data point still
doesn't exist.

---
