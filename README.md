# 9 Tiles Puzzle

A sliding-image puzzle for iOS. Fetch a photo, slice it into a grid, scramble the pieces, and put it back together across seven distinct game modes.

[//]: # (Hero section: this would benefit from a screenshot or short GIF of the puzzle grid mid-solve — no visual assets exist in the repo yet.)

## Features

### Seven ways to play

Pick a mode from the menu, each with its own twist:

- **Slide** — classic sliding-puzzle movement; a tile that reaches its spot stays draggable and can move again later
- **Swap** — swap any two tiles; a tile locks in place for good the moment it lands correctly
- **Time Trial** — race the clock, with a **Gauntlet Ladder** sub-mode: a fixed 10-stage climb of escalating grid size and difficulty
- **Limited Moves** — solve within a move budget set by the grid size
- **Zen** — untimed, no streaks to break
- **Haze** — tiles hide behind a drifting fog; shake to reveal the image before it rolls back in
- **Chaos** — the source image may be recolored, mirrored, or flipped before you even see it

### Daily Challenge

One seeded puzzle per day. A calendar view tracks your streak and lets you replay any past day.

### Five image sources

Internet (random via [picsum.photos](https://picsum.photos)), your Photos library, Mixed (either, at random), procedurally generated Numbers, and **Quick Snap** — capture a photo with the camera and play it immediately.

### Track your progress

- **Stats** — personal bests and games played, tracked per grid size and mode
- **Achievements** — 39 unlockable achievements across six categories (Milestones, Difficulty, Efficiency, Streaks, Explorer, Special)
- **Wall of Fame** — a cork board of 25 pinned record cards (best moves/time per grid size, daily bests, calendar streak, Gauntlet Ladder stages), each rendered with its own swing physics

### Live Activity and widgets

- A Live Activity tracks an in-progress puzzle on the Lock Screen and in the Dynamic Island (compact, minimal, and expanded layouts)
- Three home-screen widgets: Daily Challenge, Streaks & Records, and Resume Game
- Widgets deep-link straight back into the app via a `ninetilespuzzle://` URL scheme

### Everything else

Image preview before the shuffle, a haptics toggle, automatic resume of an in-progress game after relaunch, and a Game Center dashboard for your player profile.

## Tech stack

- SwiftUI throughout, with `@Observable`/`@MainActor` stores instead of `ObservableObject`
- Swift Concurrency (async/await) end to end
- WidgetKit and ActivityKit for the widgets, Live Activity, and Dynamic Island
- GameKit for the Game Center access point
- Persistence sits behind a `PersistenceStore` protocol backed by `UserDefaults`; an App Group shares a single JSON snapshot with the widget extension
- One third-party dependency: [Billboard](https://github.com/hiddevdploeg/Billboard) (SPM, MIT) for the free-tier cross-promo ad
- Unit tests use **Swift Testing** (`@Suite`, `@Test`, `#expect`)

See [ARCHITECTURE.md](ARCHITECTURE.md) for a deeper dive into state ownership, persistence, and the widget data-sharing model, and [ROADMAP.md](ROADMAP.md) for what's planned next.

## Requirements

- iOS 26.2+
- Xcode 26.0+
- Swift 6.2+

## Getting started

1. Open `NineTilesPuzzle.xcodeproj` in Xcode.
2. Select the `NineTilesPuzzle` scheme and run on an iOS 26.2+ simulator or device.

Run the test suite with `⌘U`, or from the command line:

```sh
xcodebuild test \
  -project NineTilesPuzzle.xcodeproj \
  -scheme NineTilesPuzzle \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project structure

```
NineTilesPuzzle/
├── Models/               # Game rules plus Stats, Daily Challenge, Achievements, Wall of Fame, and Settings stores
│   └── Image/             # Local, remote, daily-seeded, and photo-library image sources
├── Services/              # GameEngine, LiveActivityController, ImageService, GameCenterService, QuickSnapCameraSession, SoundService, MotionManager, AchievementService
├── Views/                 # MenuView, StatsView, AchievementsView, plus per-feature folders (Daily/, GameMode/, Puzzle/, Streak/, WallOfFame/, Settings/)
├── Shared/                # Types compiled into both the app and widget targets: DeepLink, PuzzleActivityAttributes, LiveActivityStore, WidgetDataStore
└── Resources/              # achievements.json, Assets.xcassets, AppIcon.icon

NineTilesPuzzleWidgets/
├── DailyChallenge/         # Home-screen widget
├── StreaksRecords/         # Home-screen widget, configurable via AppIntent
├── ResumeGame/             # Home-screen widget
└── Views/                  # Shared Live Activity, Dynamic Island, and widget components

NineTilesPuzzleTests/
└── 26 Swift Testing suites covering engines, rules, stores, services, and deep-link routing
```
