# NineTilesPuzzle

An iOS puzzle game that fetches a random image, slices it into a 3×3 grid, shuffles the tiles, and challenges you to restore the original image by dragging tiles into place.

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 6.2+

## How it works

Opening the app shows a home screen where you can see the puzzle configuration — size (3×3) and photo source (random) — before you start. Tap **Play** to begin.

The app fetches a random 1024×1024 image from [picsum.photos](https://picsum.photos/1024). If the network is unavailable it falls back to a bundled image. The image is sliced into nine equal tiles that are shuffled into a random order.

Drag any tile over another to swap their positions. A tile that lands on its correct cell is locked in place and can no longer be moved. Solve the puzzle by locking all nine tiles. A "Puzzle complete!" alert appears when you finish — tap **Play again** to start a new round with a fresh image, or **Main Menu** to return to the home screen.

Game state (tile positions and the source image) is persisted to `UserDefaults`, so a mid-game session is restored automatically when you relaunch the app.

## Project structure

```
NineTilesPuzzle/
├── Models/
│   ├── GameRoute.swift          # Typed navigation route for NavigationStack
│   ├── TileModel.swift          # Observable tile — id, currentIndex, isLocked
│   ├── PuzzleState.swift        # Root observable state; owns services and persistence
│   └── Image/
│       ├── ImageSource.swift    # Protocol for image-fetching backends
│       ├── RemoteImageSource.swift
│       ├── LocalImageSource.swift
│       └── ImageSourceError.swift
├── Services/
│   ├── ImageService.swift       # Loads image; falls back on URLError
│   ├── ImageSlicer.swift        # Crops a CGImage into an N×N tile grid
│   └── PuzzleEngine.swift       # Shuffle, swap, and solved-state logic
└── Views/
    ├── HomeView.swift            # Menu screen; owns NavigationStack and route path
    ├── PuzzleView.swift          # Root game view; routes loading / error / grid states
    ├── PuzzleGridView.swift      # ZStack-based drag-and-drop tile grid
    ├── TileView.swift            # Single draggable tile with Reduce Motion support
    ├── LoadingView.swift         # Spinner shown while the image loads
    └── PuzzleErrorView.swift     # Error state with retry button

NineTilesPuzzleTests/
├── ImageServiceTests.swift      # Fallback behaviour under URLError
├── ImageSlicerTests.swift       # Tile count and dimensions
└── PuzzleEngineTests.swift      # Shuffle, swap, and isSolved contracts
```

## Architecture

- **Swift 6** strict concurrency throughout; all `@Observable` classes are `@MainActor`.
- State is owned by `PuzzleState` (`@State` in `NineTilesPuzzleApp`) and injected via `.environment(_:)`.
- Navigation uses `NavigationStack` with a typed `GameRoute` path, owned by `HomeView`.
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
