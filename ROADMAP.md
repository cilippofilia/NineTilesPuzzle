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

[] ### Daily Challenge — **M**
One puzzle per day, identical for every player: seed the shuffle deterministically from the
date (`GameEngine.shuffle` would accept a `RandomNumberGenerator`) and use a fixed image per
day (a bundled pack indexed by date, or a date-seeded picsum ID). Track a calendar streak of
completed days, separate from the in-game move streak. This is the single highest-leverage
feature for retention, and the natural companion to an online leaderboard (see §3).

[X] ### Time Attack — **S/M**
Shipped as Time Trial mode (MVP scope, June 2026): one timed puzzle per grid size, with a
flat combo bonus/misplay penalty per move and a simplified score formula. Reused the streak
countdown timer's `Task`-based shape in `GameSession` almost exactly, generalized from "time
per correct move" to "time per puzzle" — see `ARCHITECTURE.md` for the implementation.

The full 10-stage **Gauntlet Ladder** progression also shipped (June 2026), as a toggle
inside Time Trial rather than a new mode — see `ARCHITECTURE.md` for the implementation.
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

[] ### Fog / Reveal Mode — **M**
Tiles start desaturated or hidden and reveal in full color only when locked, with no image
preview. A visual-twist mode built almost entirely in `TileView` rendering, on top of the
existing lock state.

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

### Menu stats card — **S** *(removed June 2026, needs a mode-aware rebuild)*
The streak/best-moves card on `MenuView` was removed because it only had real data for
Swap and Slide — `GameSession.currentStreakForCurrentSize`/`allTimeHighStreakForCurrentSize`
are never incremented for Zen, Time Trial, or Limited Moves (they track games-played or
score instead, see `registerMove` in `GameSession.swift`), so the card showed dead zeros for
those modes. Re-add only with per-mode-appropriate content: streak + best moves for
Swap/Slide, best score for Time Trial, best moves for Limited Moves, and likely nothing (or
games-played) for Zen — gated behind a small `GameMode` capability check rather than always
rendering the same `StreakStatsView`.

---

## 5. Achievements Overhaul

Take inspiration from Apple Fitness awards: badges grouped by category, tiered medals with
progress shown toward the next tier, earned dates, and occasional limited-edition awards.
Today the system is 10 flat achievements with a binary `isUnlocked` flag and a hardcoded
`switch` in `AchievementsStore.checkAchievements(using:)` — most of this section starts
with making definitions data-driven.

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
(`isLadderMode`), not a new `GameMode`. Revisit again if a third budget-based mode arrives;
neither Fog/Reveal nor Chaos (this section's remaining unshipped modes) is budget-shaped, so
that third data point doesn't exist yet.

---
