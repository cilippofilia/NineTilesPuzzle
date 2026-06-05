# Nine Tiles

A sliding tile puzzle for iOS. The app fetches an image, slices it into a grid, shuffles the pieces, and challenges you to restore the original by dragging tiles into place.

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 6.2+

## How it works

The home screen shows your current streak, best streak, and the active settings before you start. Tap **Play** to begin.

The app fetches a random 1024×1024 image from [picsum.photos](https://picsum.photos). You can also choose a photo from your library, or let it pick randomly between both sources. The image is sliced into an N×N grid and the tiles are shuffled.

Drag any tile over another to swap their positions. A tile that lands on its correct cell locks in place and can no longer be moved. Solve the puzzle by locking all tiles. When you finish, the completion banner shows your final streak count — tap **Continue** to start a new round with a fresh image.

Game state (tile positions and source image) is saved to `UserDefaults` and restored automatically on relaunch.

## Features

- **Six difficulty levels** — Easy (3×3) through Insane (8×8)
- **Three image sources** — random from the internet, from your photo library, or mixed
- **Streak tracking** — consecutive correct moves tracked across games, with an all-time high that persists between sessions
- **Auto-lock** — tiles snap and lock as soon as they reach their correct position
- **State persistence** — resume any in-progress game after relaunching the app

## Project structure

```
NineTilesPuzzle/
├── Models/
│   ├── TileModel.swift              # Observable tile — id, currentIndex, isLocked
│   ├── PuzzleState.swift            # Root observable state; owns services and persistence
│   └── Image/
│       ├── ImageSourceType.swift
│       ├── ImageSourceError.swift
│       ├── LocalImageSource.swift
│       ├── PhotoLibraryImageSource.swift
│       └── RemoteImageSource.swift
├── Services/
│   ├── ImageService.swift           # Loads image; falls back on URLError
│   ├── ImageSlicer.swift            # Crops a CGImage into an N×N tile grid
│   └── PuzzleEngine.swift           # Shuffle, swap, and solved-state logic
└── Views/
    ├── MenuView.swift               # Home screen with streak stats, settings, and Play
    ├── PuzzleView.swift             # Root game view; routes loading / error / grid states
    ├── PuzzleGridView.swift         # Drag-and-drop tile grid
    ├── TileView.swift               # Single draggable tile
    ├── StreakCounterView.swift      # In-game streak badge
    ├── StreakStatsView.swift        # Menu streak summary card
    ├── CompletionBannerView.swift   # Post-solve banner with streak and record callout
    ├── GridSizePickerView.swift     # Difficulty picker
    ├── PhotoSourcePickerView.swift  # Image source picker
    ├── LoadingView.swift
    └── PuzzleErrorView.swift

NineTilesPuzzleTests/
├── PuzzleEngineTests.swift          # Shuffle, swap, and isSolved contracts
├── ImageSlicerTests.swift           # Tile count and dimensions
└── ImageServiceTests.swift          # Fallback behaviour under URLError
```

## Architecture

- **Swift 6** strict concurrency throughout; all `@Observable` classes are `@MainActor`.
- State is owned by `PuzzleState` and injected via `.environment(_:)`.
- Navigation uses `NavigationStack` with a typed `GameRoute` path, owned by `MenuView`.
- Services (`ImageService`, `ImageSlicer`, `PuzzleEngine`) are stateless value types called directly from `PuzzleState`.
- Image persistence uses `CGImageDestination` (ImageIO) for JPEG encoding and `JSONEncoder` for tile data — no UIKit dependency.
- Tests use **Swift Testing** (`@Suite`, `@Test`, `#expect`).

## Running the tests

Open `NineTilesPuzzle.xcodeproj` in Xcode and press `⌘U`, or run from the command line:

```sh
xcodebuild test \
  -project NineTilesPuzzle.xcodeproj \
  -scheme NineTilesPuzzle \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
