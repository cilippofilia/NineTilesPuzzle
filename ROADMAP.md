# NineTilesPuzzle — Improvement Roadmap

Each idea has an effort estimate — **S** (hours), **M** (days), **L** (a week or more) — and
notes on how it hooks into the existing architecture.

---

## 1. New Game Modes

All modes reuse the stateless `PuzzleEngine` and `PuzzleState`. The natural starting point is
a `GameMode` enum threaded through `PuzzleState`, with mode selection routed via the existing
`GameRoute` enum in `Views/MenuView.swift`.

[] ### Daily Challenge — **M**
One puzzle per day, identical for every player: seed the shuffle deterministically from the
date (`PuzzleEngine.shuffle` would accept a `RandomNumberGenerator`) and use a fixed image per
day (a bundled pack indexed by date, or a date-seeded picsum ID). Track a calendar streak of
completed days, separate from the in-game move streak. This is the single highest-leverage
feature for retention, and the natural companion to an online leaderboard (see §3).

[] ### Time Attack — **S/M**
Solve the whole puzzle before a countdown expires, with time budget scaled by grid size.
The streak countdown timer in `PuzzleState` already provides the timer infrastructure —
this generalizes it from "time per correct move" to "time per puzzle".

[] ### Limited Moves — **S**
Solve within a move budget per difficulty. The move counter already exists; this only adds
a budget check and a fail state. Pairs naturally with the power-up economy (§2).

[] ### Zen Mode — **S**
No timers, no streak pressure, no fail states — just the picture. Cheapest mode to build
because it *disables* existing systems rather than adding new ones. Good for the audience
that plays with personal photos.

[X] ### Classic Slide (15-puzzle variant) — **M/L**
One empty cell, tiles slide instead of swap. Needs new engine rules (legal-move adjacency
and a solvability parity check on shuffle — half of random permutations are unsolvable) but
reuses the entire image-slicing and grid-rendering pipeline. Effectively a second game in
the same app.

[] ### Fog / Reveal Mode — **M**
Tiles start desaturated or hidden and reveal in full color only when locked, with no image
preview. A visual-twist mode built almost entirely in `TileView` rendering, on top of the
existing lock state.

---

## 2. Power-ups & Twists

Earned rather than bought (at least initially): award them at streak milestones, achievement
unlocks, and daily-challenge completions. Inventory is a handful of counters persisted in
UserDefaults alongside the existing `PuzzleState.Keys`. Each one is small because the
mechanics it manipulates already exist:

| Power-up | Effort | How it works |
|---|---|---|
| **Peek** | S | Re-show the full image mid-game for a few seconds — `ImagePreviewView` already does this pre-shuffle. |
| **Hint** | S | Briefly highlight where one selected tile belongs. |
| **Auto-place** | S | Lock one random unlocked tile into its correct cell via the existing swap/lock logic. |
| **Streak Freeze** | S | Pause the streak countdown once per game. |
| **Re-shuffle** | S | Reshuffle only the unlocked tiles (a constrained `PuzzleEngine.shuffle`) when stuck. |

**Economy note:** milestone-based earning keeps the game fully offline-friendly and
pressure-free. If monetization ever lands (§4), power-up bundles become an obvious IAP
without redesigning anything.

---

## 3. Game Center / Online

The biggest new capability, and the cheapest path to "online": GameKit needs no custom
backend. Prerequisite is Game Center configuration in App Store Connect (leaderboard and
achievement IDs).

### Leaderboards — **M**
The stats are already tracked in `PuzzleState`; submission is a thin `GameCenterService`:
- Best moves per difficulty (six leaderboards, one per grid size)
- All-time best streak
- Daily challenge: recurring leaderboard for moves (and time, once Time Attack exists)

### Achievements sync — **M**
Mirror the 10 local achievements (`Resources/achievements.json`) to Game Center, reporting
on unlock. Keep the local system as the source of truth so the game still works fully
offline. While in this area: `AchievementService.remoteURL` still points at
`example.com` — either wire up a real hosted JSON or remove the remote path.

### Access point — **S**
`GKAccessPoint` on the menu screen gives players the Game Center profile/leaderboard UI
for free.

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
- Pause timers when the app is backgrounded (streak countdown currently runs on wall clock).
- Share a completed puzzle as an image via `ImageRenderer`.
- First-launch tutorial overlay explaining drag-to-swap and locking.
- Accessibility audit — drag-to-swap needs a VoiceOver-friendly alternative (e.g.
  select-then-place via accessibility actions).

---

## 5. Achievements Overhaul

Take inspiration from Apple Fitness awards: badges grouped by category, tiered medals with
progress shown toward the next tier, earned dates, and occasional limited-edition awards.
Today the system is 10 flat achievements with a binary `isUnlocked` flag and a hardcoded
`switch` in `PuzzleState+Achievements.swift` — most of this section starts with making
definitions data-driven.

### Data-driven model with progress — **M** *(foundation for everything below)*
Extend `Achievement` and `achievements.json` so each definition carries a `category`, a
`metric` (e.g. `totalGames`, `bestStreak`, `personalBestMoves.3`, `gamesPlayed.8`), and a
`target`. `checkAchievements()` then becomes a generic "metric ≥ target" evaluation instead
of a per-id `switch`, and **progress is free**: current metric value ÷ target. Also persist
the unlock *date* alongside the existing UserDefaults flag (Fitness always shows "Earned
12 Jun 2026"). Existing ids keep working — migration is just leaving the current keys as-is.

### Categories — **S** *(after the model work)*
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

### Progress bars — **S** *(falls out of the data-driven model)*
Show progress toward the next locked tier wherever an achievement appears:
`AchievementRowView` gets a `ProgressView(value:)` or circular `Gauge` ("37/50 puzzles"),
and locked badges render greyed-out with the bar underneath — exactly how Fitness shows
unearned awards. One-shot achievements (e.g. "solve an 8×8") stay binary, no bar.

### New achievements — **S each** *(once the model is data-driven, these are JSON entries)*
- **Perfectionist**: solve a puzzle where every move locks a tile (zero wasted moves)
- **Marathon**: solve 5 puzzles in one day
- **Night Owl / Early Bird**: solve between midnight–5am / before 7am
- **Personal Touch**: solve a puzzle using a photo-library image
- **Comeback**: rebuild a streak to 10+ right after one breaks
- **Full House**: complete every grid size at least once
- **Sharpshooter**: beat your own personal best three times on the same grid size
- Future-mode hooks: daily-challenge calendar streaks (7 / 30 days — see §1), Zen and
  Time Attack first-clears, power-up-free solve on 6×6+

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

## 6. Current Game Mode Architecture (snapshot)

```
┌─────────────────────────────────────────────────────────────────┐
│                          MenuView                                │
│        (picks: game mode, difficulty, image source...)           │
└───────────────────────────┬───────────────────────────────────────┘
                             │ NavigationStack(.game)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         PuzzleView                                │
│   (renders grid/preview/loading/error, observes PuzzleState)     │
└───────────────────────────┬───────────────────────────────────────┘
                             │ reads/calls
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PuzzleState (@Observable)                     │
│  single source of truth: tiles, mode, streaks, moves, settings   │
│                                                                   │
│   selectedGameMode: GameMode  ───────►  activeEngine (computed)  │
│                                                                   │
└──────────┬───────────────────────────────────────┬────────────────┘
           │ delegates shuffle/move/isSolved        │
           ▼                                        ▼
   ┌───────────────────┐                  ┌───────────────────┐
   │   ClassicEngine    │                  │   SlideEngine      │
   │  (swap any 2 tiles)│                  │ (slide into blank) │
   └───────────────────┘                  └───────────────────┘
           ▲                                        ▲
           └────────────────┬───────────────────────┘
                             │ both conform to
                  ┌──────────────────────┐
                  │  GameEngine protocol  │
                  │  - shuffle(tiles:)     │
                  │  - isSolved() (shared) │
                  └──────────────────────┘
```

**`GameMode`** (`Models/GameMode.swift`) — flat `enum` with 7 cases: `classic`, `slide`,
`timeTrial`, `limitedMoves`, `zen`, `fog`, `chaos`. Each has `title`, `description`, `icon`,
and an `isAvailable` flag. Only `.classic` and `.slide` are available today — the rest show
as "Coming soon…" in `GameModeView`. The enum is purely presentational metadata; it carries
no gameplay logic itself.

**`GameEngine`** (`Services/GameEngine.swift`) — the contract every mode implements:
`shuffle(tiles:gridSize:) -> [TileModel]`, plus a shared default `isSolved()`. This is the
extension point for new modes.

**`ClassicEngine`** / **`SlideEngine`** — the only two concrete engines. Classic shuffles
into a derangement and swaps any two unlocked tiles, locking ones that land correctly. Slide
shuffles into a parity-checked solvable permutation and only slides into the adjacent blank
cell. Each owns mode-specific methods beyond the protocol (`swap`, `slide`, `areAdjacent`)
since move semantics differ per mode.

**`PuzzleState`** — owns everything: tile array, both engine instances, a computed
`activeEngine` that switches on `selectedGameMode` (currently binary: `slide` vs. "everything
else → classic"), streak/move/achievement bookkeeping, persistence, and the image pipeline.
`PuzzleView` branches on mode directly to decide which engine call to wire up to gestures.

**`SlideSolver`** — standalone BFS/reduction solver, used only by a debug "Solve" button,
mode-gated to `.slide`.

**Architectural gap for the modes above:** none of Time Trial / Limited Moves / Zen / Fog /
Chaos need a new `GameEngine` — they're modifiers on top of Classic/Slide's move rules, not
new move rules. But today there's only one axis (which engine handles shuffle/move); there's
no home yet for "is there a timer," "is there a move budget," "is failure possible." Building
each mode as more `if selectedGameMode == .x` branches in `PuzzleState` will compound. Worth
introducing a small composable `GameModeRules` (timer budget, move budget, fail condition)
that pairs with an engine, rather than letting `PuzzleState` accumulate mode-conditionals.

---
