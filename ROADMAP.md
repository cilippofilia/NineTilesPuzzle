# NineTilesPuzzle — Improvement Roadmap

Each idea has an effort estimate — **S** (hours), **M** (days), **L** (a week or more) — and
notes on how it hooks into the existing architecture. Shipped features and their
implementation details live in `ARCHITECTURE.md`; this file tracks what's still outstanding.

---

## 1. New Game Modes

Six of seven originally-sketched modes have shipped — Slide, Swap, Time Trial (with the
Gauntlet Ladder sub-mode), Limited Moves, Zen, Haze, and Chaos, all routed through
`GameSession` via the `GameMode` enum in `Views/Menu/MenuView.swift`. See `ARCHITECTURE.md` for
how `GameSession`, `StatsStore`, `SettingsStore`, and `AchievementsStore` fit together.
Outstanding follow-ups on shipped modes:

### Daily Challenge
- Leaderboard for daily challenge (§3 prerequisite for comparison across players).
- Calendar streak achievements (7 / 30 days) — deferred until §5 achievements overhaul.
- Replay limit / "come back tomorrow" gate — today the player can replay the same puzzle to
  improve best moves/time; the calendar streak only advances once per day.

### Time Trial / Gauntlet Ladder
- The Endless "Ghost Mode" (stage 11+), racing the player's own personal best pace.
- Time-banking: carrying over a percentage of leftover time between ladder stages.
- The low-time vignette pulse and BPM-escalating audio sensory layer (the countdown
  currently only recolors text).
- Restricting Time Trial to a curated, high-contrast image source for leaderboard fairness.

**Backgrounding/interruption resume grace — shipped (2026-07-16):** `scenePhase` handling now
distinguishes `.background` (real backgrounding) from `.inactive` (phone call, Face ID prompt,
Control Center, app-switcher preview) — both freeze the countdown via `pauseTimers()`, but only
returning to `.active` mid-run triggers a 3-2-1 "Get Ready" grace period
(`TimeTrialResumeOverlay`) before `resumeTimers()` actually restarts the clock, so the countdown
never resumes ticking the instant the screen becomes visible again. See `ARCHITECTURE.md`.

### Limited Moves
- Power-ups (§2, shipped) already work here with no special-casing needed — not gated by
  game mode.
- The move-budget table could use difficulty-based tuning passes if playtesting shows the
  flat numbers are too generous/strict.

### Quick Snap
- Landscape capture / orientation-locked framing UI (the frame is normalized upright on
  capture, but the countdown UI assumes portrait).

### Gravity Mode — **M** *(not started)*
A tilt-to-play mode: the player holds their phone and all tiles simultaneously slide toward
the direction of gravity. Tilt left → every tile drifts left until it hits the wall or
another tile; tilt right → same in reverse; and so on for up/down. The mechanic is
fundamentally different from Slide (where you drag one tile into the adjacent blank cell)
because every tile moves at once — the empty space(s) collect at the "high" side of the
board, and the order in which you make moves matters at a whole-board level.

**Status:** Core gravity detection infra is already in place. `MotionManager` derives
`pitch`/`roll` from `CMDeviceMotion.gravity` (real-world "down", drift-free) at 60 Hz
pull-based updates. The gravity-feel system is used by Wall of Fame's card physics and is
unit-tested without CoreMotion.

Architecture hooks:
- Add `.gravity` to the `GameMode` enum and a `GravityEngine: GameEngine` in `Services/`.
  `shuffle()` can delegate to `SwapEngine`'s derangement shuffle since any state is
  solvable under gravity rules (no parity constraint). The engine exposes a
  `slide(direction:)` method that iterates columns/rows and cascades tiles toward the wall.
- `GameSession` gets a `gravitateBoard(direction: GravityDirection)` entry point (analogous
  to `slideTile(from:)`) that calls the engine and then `registerMove()`.
- Motion input hooks into the existing `MotionManager` service (already `@Observable
  @MainActor` wrapping `CMMotionManager` with gravity-fused tilt output at 60 Hz).
  Gravity vector from `motionManager.roll`/`motionManager.pitch` maps to a discrete
  direction once a tilt threshold is crossed; a cooldown prevents repeated triggers on
  a single deliberate tilt.
- `PuzzleGridView` embeds a tilt listener (similar to the existing `ShakeDetector` pattern
  in `Views/Helpers/`) that calls `session.gravitateBoard(direction:)` on threshold
  crossings. Drag gestures can be disabled entirely for this mode.
- A tilt-direction indicator (arrow or subtle board-edge highlight) gives the player
  real-time feedback on which way the tiles will slide.

Still to decide: whether to use a discrete threshold (snap to the dominant axis) or a
continuous tilt that lets tiles slide diagonally. Discrete is simpler to implement and
likely more fun to play.

---

## 2. Power-ups & Twists — shipped (2026-07-07)

All five originally-sketched power-ups shipped exactly as planned: **Peek**, **Hint**,
**Auto-place**, **Streak Freeze**, **Re-shuffle** (`Models/PowerUps/`). Earned (not bought) at
streak milestones (every 5), achievement unlocks, and Daily Challenge completions; spent
mid-game via `GameSession`'s `use…PowerUp()` methods, each gated on mode/media applicability.
See `ARCHITECTURE.md`'s Power-ups section for the full mechanics. Still outstanding:
- Challenge Friends completion doesn't earn a power-up (unlike Daily) — see §3, decide if
  intentional.
- **Economy note (still relevant):** if monetization ever lands (§4), power-up bundles become
  an obvious IAP without redesigning anything.

---

## 3. Game Center / Online

GameKit needs no custom backend. Prerequisite is Game Center configuration in App Store
Connect (leaderboard and achievement IDs). The dashboard access point has shipped
(`GKAccessPoint`, see `ARCHITECTURE.md`); submission is still outstanding.

### Leaderboards — **M**
The stats are already tracked in `StatsStore`; submission is a thin `GameCenterService`:
- Best moves per difficulty (six leaderboards, one per grid size)
- All-time best streak
- Daily challenge: recurring leaderboard for moves (and time)

### Achievements sync — **M**
Mirror the 42 local achievements (`Resources/achievements.json`) to Game Center, reporting
on unlock. Keep the local system as the source of truth so the game still works fully
offline. While in this area: `AchievementService.remoteURL` still points at
`example.com` — either wire up a real hosted JSON or remove the remote path.

### Challenge Friends — shipped (2026-07-08 → 2026-07-12)
Send a friend a seeded puzzle and compare move counts/time — shipped as a fully
self-contained feature (no backend), well beyond the original "send + compare moves, wait
for leaderboards" sketch. Two transports share one payload: a custom `.ntpchallenge` file
(`Transferable`, ShareLink/AirDrop/Messages/Files, with a `QLThumbnailProvider` extension
rendering a branded preview instead of a generic document icon) and a real-time nearby
transport (migrated from Multipeer to Network.framework — `NWListener`/`NWBrowser`/
`NWConnection` over Bonjour, peer-to-peer/AWDL enabled). `ChallengeStore` tracks win/lose/tie
history with "Challenge Them Back" chains; malformed/unreadable/version-mismatched files
surface a proper "Couldn't Open Challenge" alert instead of silently no-opping. Achievement
metrics (`.challengesSent`, `.challengesWon`, `.challengesPlayed`) are wired up. See
`ARCHITECTURE.md` and this project's memory for full detail.

**Gated behind Settings (2026-07-16):** pending the manual two-device verification below, the whole feature —
menu entry, sending eligibility, and receiving `.ntpchallenge` files (an alert explains why a
tapped file won't open) — is hidden behind an off-by-default "Enable Challenge Friends" toggle
in Settings' Dev Tools section, the same pattern as Power-ups. The three Challenge Friends
achievements (`firstChallengeSent`, `firstChallengeWon`, `challengeChampion`) are likewise
excluded from the Achievements list/tally and can't unlock while the toggle is off — see §5.

Still outstanding:
- **Manual two-device verification** — neither transport (file or nearby) has been
  end-to-end tested on two physical devices; Simulator can't do Bonjour discovery or real
  share-sheet destinations.
- **Image quality degradation in shared images** — reports of low-quality images on the
  receiving end; check compression during transfer/encode/decode and Messages/AirDrop-side
  re-compression.
- Power-ups can be *spent* during a challenge game but none are *earned* from completing
  one (unlike Daily Challenge's completion path) — decide if that asymmetry is intentional.
- No Game Center leaderboard/achievement tie-in yet (ties into this section generally).

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

### Widgets — follow-ups
Three home-screen widgets (Daily Challenge, Streaks & Records, Resume Puzzle) plus deep
links have shipped — see `ARCHITECTURE.md` §Home-screen widgets. Since then: the Daily
Challenge widget was redesigned and consolidated (2026-07-12) with a Duolingo-style streak
row and a configurable "Show Puzzle Photo" option (`WidgetConfigurationIntent`, off by
default) that overlays the day's seeded photo on the puzzle-piece watermark; a daily
reminder local notification also shipped (configurable time, rotating message pool, skips a
day already completed); and the Live Activity/Dynamic Island gained its own `widgetURL`
(2026-07-16) — tapping it now resumes the in-progress game via the existing
`ninetilespuzzle://resume` deep link instead of just opening the app. Still outstanding:
- Lock Screen / StandBy accessory widgets, if revisited later.
- StandBy/tinted-mode polish pass on real hardware (accented rendering is wired via
  `widgetAccentedRenderingMode(.accentedDesaturated)` but only Simulator-verified).

### Monetization *(optional, later)* — **L**
Lightest-touch options first: tip jar, then premium image packs and power-up bundles via
StoreKit 2. Nothing in the current architecture blocks this; the power-up economy and image
packs are designed to make it bolt-on.

### Smaller polish — **S each**
- [ ] Accessibility audit — drag-to-swap needs a VoiceOver-friendly alternative (e.g.
  select-then-place via accessibility actions).

### Performance pass — follow-ups
A profiling-driven pass shipped (see `ARCHITECTURE.md` §Persistence and the Haze section for
details). Still deferred: Instruments before/after captures on a Release build (Time
Profiler around `registerMove`, Animation Hitches on an 8×8 Fog board) to quantify the wins.

### Wall of Fame — follow-ups
The cork-board of auto-pinned personal records has shipped (see `ARCHITECTURE.md`). Both
follow-ups tracked here shipped 2026-07-16:
- Manual curation — long-press a card for "Unpin from Wall" (or "Re-pin to Wall" on an
  already-hidden slot) and "Move Earlier"/"Move Later" reordering within its section, both
  persisted.
- The zoomed overlay's Share button moved off the nav bar into `ZoomedCardOverlay`'s own
  footer slot.

No outstanding items here currently.

---

## 5. Achievements Overhaul

Take inspiration from Apple Fitness awards: badges grouped by category, tiered medals with
progress shown toward the next tier, earned dates, and occasional limited-edition awards.
The data-driven model, categories, and progress bars have all shipped (see
`ARCHITECTURE.md`).

**Challenge Friends gating (2026-07-16):** while Challenge Friends is off in Settings (§3),
`AchievementMetric.isChallengeFriendsMetric` flags the three metrics that read
`ChallengeStore` (`.challengesSent`/`.challengesWon`/`.challengesPlayed`), and
`AchievementsStore` excludes their achievements (`firstChallengeSent`, `firstChallengeWon`,
`challengeChampion`) from `checkAchievements`, the visible list, and the "x/y" tally — they
simply don't appear, the same way the feature itself is hidden from the menu. Completionist
excludes them from its "every other achievement" requirement too while disabled, so it can
still unlock without the player ever touching Challenge Friends. The now-empty "Social"
category section is skipped entirely in `AchievementsView` rather than rendering a bare
header. Turning Challenge Friends on reinstates all three immediately (locked, in progress).

Outstanding:

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

### New achievements — follow-ups
- **Sharpshooter** (beat personal best 3× on same grid size) — needs a new `StatsStore`
  counter; deferred until §3 leaderboard work makes per-grid-size tracking richer.
- Daily-challenge calendar streaks (7 / 30 days) — blocked on Daily Challenge leaderboard
  work above.

### Fitness-style extras — **M** *(later, once the above ships)*
- **Limited-edition awards**: seasonal badges (New Year solve, app anniversary) — this is
  the actual payoff of the existing remote-fetch infrastructure in `AchievementService`,
  since limited editions can be pushed without an app update.
- **Monthly challenge**: one personalized goal per month computed from the player's own
  stats ("Solve 20 puzzles in June"), shown as a card with a progress ring on the menu.
- **Badge detail sheet**: tapping a badge opens a large rendering with earned date, tier
  history, and a share button (`ImageRenderer`) — same shape as the Wall of Fame's zoomed-card
  Share button (§4, shipped).
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

**Open question:** `GameMode` is 7 cases, and mode-specific behavior (`isZenMode`,
`isTimeTrialMode`, `isLimitedMovesMode`, `selectedGameMode == .slide`, debug-overlay gating)
is still scattered conditionals inside `GameSession` and `PuzzleView`/`PuzzleGridView` rather
than a single abstraction. A small composable `GameModeRules` has been considered multiple
times — Time Trial and Limited Moves do share a real "budget + fail condition, checked after
the solved branch" axis, unlike Zen, which only disables tracking — but conditionals won
each time: the two budgets differ enough in kind (mutable wall-clock time with a combo score
vs. a flat decrementing move count with no score) that a shared struct would carry fields
meaningless to one conformer or the other, for a payoff of collapsing two small `if`/`else
if` branches. See `ARCHITECTURE.md`'s §6 resolution for the full reasoning. Gauntlet Ladder,
Chaos, and Haze don't add a data point either — none are budget-based. All originally-planned
modes are now live except Gravity Mode (§1); revisit the `GameModeRules` question if Gravity
Mode turns out to need a third budget-based shape, or defer it again if it doesn't.

---
