//
//  GameSession.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

/// The game currently configured and/or in progress: which mode/size/media to play, the
/// live board, and the timers that run while playing. Reports completed moves and games to
/// `StatsStore` and `AchievementsStore`, and reads `SettingsStore` for preferences that
/// affect play (preview length, streak countdown length, debug/practice mode).
@MainActor
@Observable
final class GameSession {
    private let statsStore: StatsStore
    private let achievementsStore: AchievementsStore
    private let settingsStore: SettingsStore
    private let defaults: PersistenceStore

    private let classicEngine = ClassicEngine()
    private let slideEngine = SlideEngine()
    private var previewSleepTask: Task<Void, Never>?

    var gridSize: Int = 3
    var useRandomSize: Bool = false
    var mediaSourceType: MediaSourceType = .random
    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    /// The center-cropped square `sourceImage` is sliced from — what tiles actually show,
    /// used to reveal the complete picture on solve without a mismatched, uncropped edge.
    var croppedSourceImage: CGImage?
    var isLoading = false
    var isPreviewing = false
    var isSolved = false
    var isNewRecord: Bool = false
    var currentMoveCount: Int = 0
    var isNewMovesRecord: Bool = false
    var elapsedTime: TimeInterval = 0
    var isNewBestTime: Bool = false
    var error: Error?
    var selectedGameMode: GameMode = .classic

    private(set) var timerRemaining: Double = 30
    private(set) var isTimerRunning = false
    private(set) var didBreakStreak = false

    private var countdownTask: Task<Void, Never>?
    private var stopwatchTask: Task<Void, Never>?

    /// Zen mode tracks nothing but the number of games played: no streaks, no personal
    /// bests, no achievements — just an uninterrupted, judgment-free puzzle loop.
    var isZenMode: Bool { selectedGameMode == .zen }

    var currentStatsKey: StatsKey { StatsKey(gridSize: gridSize, gameMode: selectedGameMode) }

    private var activeEngine: any GameEngine {
        switch selectedGameMode {
        case .slide:
            return slideEngine
        default:
            return classicEngine
        }
    }

    init(
        statsStore: StatsStore,
        achievementsStore: AchievementsStore,
        settingsStore: SettingsStore,
        defaults: PersistenceStore = UserDefaults.standard
    ) {
        self.statsStore = statsStore
        self.achievementsStore = achievementsStore
        self.settingsStore = settingsStore
        self.defaults = defaults
        restoreFromUserDefaults()
        achievementsStore.checkAchievements(using: statsStore)
        Task {
            await achievementsStore.refreshAchievementsFromRemote()
            achievementsStore.checkAchievements(using: statsStore)
        }
    }

    func startCountdown() {
        guard settingsStore.streakCountdownDuration > 0 else { return }
        stopCountdown()
        timerRemaining = settingsStore.streakCountdownDuration
        isTimerRunning = true
        let end = Date.now.addingTimeInterval(settingsStore.streakCountdownDuration)
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    statsStore.resetStreak(for: currentStatsKey)
                    isNewRecord = false
                    didBreakStreak.toggle()
                    stopCountdown()
                    return
                }
                timerRemaining = remaining
            }
        }
    }

    func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        timerRemaining = settingsStore.streakCountdownDuration
        isTimerRunning = false
    }

    /// Starts (or resumes) the elapsed-time stopwatch, anchored so a resumed game continues
    /// from its persisted `elapsedTime` rather than restarting at zero.
    func startStopwatch() {
        stopwatchTask?.cancel()
        let start = Date.now.addingTimeInterval(-elapsedTime)
        stopwatchTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                elapsedTime = Date.now.timeIntervalSince(start)
            }
        }
    }

    func stopStopwatch() {
        stopwatchTask?.cancel()
        stopwatchTask = nil
    }

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state. In `.numbers`
    /// media mode there is no image to fetch or preview — tiles are shuffled immediately.
    func startNewGame() async {
        if useRandomSize { gridSize = Int.random(in: 3...8) }
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        isLoading = true
        isSolved = false
        isNewRecord = false
        currentMoveCount = 0
        isNewMovesRecord = false
        elapsedTime = 0
        isNewBestTime = false
        error = nil

        let initial = (0..<gridSize * gridSize).map {
            TileModel(id: $0, currentIndex: $0, isLocked: false)
        }

        guard mediaSourceType != .numbers else {
            isLoading = false
            tiles = activeEngine.shuffle(initial, gridSize: gridSize)
            if currentStreakForCurrentSize > 0 { startCountdown() }
            saveToUserDefaults()
            return
        }

        do {
            let source: any ImageSource = switch mediaSourceType {
            case .local: PhotoLibraryImageSource()
            case .mixed: Bool.random() ? RemoteImageSource() : PhotoLibraryImageSource()
            default: RemoteImageSource() // covers .random; .numbers is handled above
            }
            let isRemote = source is RemoteImageSource
            let image = try await ImageService(primarySource: source).loadImage()
            sourceImage = image

            let slicer = ImageSlicer()
            croppedSourceImage = slicer.centerCrop(image)
            let slices = slicer.slice(image, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            isLoading = false

            if isRemote && settingsStore.previewDuration > 0 {
                isPreviewing = true
                previewSleepTask = Task { try? await Task.sleep(for: .seconds(settingsStore.previewDuration)) }
                await previewSleepTask?.value
                previewSleepTask = nil
                isPreviewing = false
            }

            tiles = activeEngine.shuffle(initial, gridSize: gridSize)
            if currentStreakForCurrentSize > 0 { startCountdown() }
            saveToUserDefaults()
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Attempts to swap the tiles at `sourceIndex` and `targetIndex`; no-ops if either is locked or indices are equal.
    func swapTiles(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else { return }
        guard
            let source = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let target = tiles.first(where: { $0.currentIndex == targetIndex }),
            !source.isLocked,
            !target.isLocked
        else { return }

        let correctBefore = tiles.filter { $0.isCorrect }.count
        classicEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        registerMove(correctBefore: correctBefore)
    }

    /// Attempts to slide the tile at `sourceIndex` into the empty cell; no-ops unless they're adjacent.
    /// Returns whether a move occurred.
    @discardableResult
    func slideTile(from sourceIndex: Int) -> Bool {
        guard
            let blankIndex = slideEngine.blankIndex(in: tiles),
            blankIndex != sourceIndex,
            slideEngine.areAdjacent(sourceIndex, blankIndex, gridSize: gridSize)
        else { return false }

        let correctBefore = tiles.filter { $0.isCorrect }.count
        slideEngine.slide(&tiles, from: sourceIndex, gridSize: gridSize)
        registerMove(correctBefore: correctBefore)
        return true
    }

    /// Shared bookkeeping after a move: move count, solved/streak/records, achievements, and persistence.
    private func registerMove(correctBefore: Int) {
        // The stopwatch starts on the first move, not at game start, so memorizing the
        // preview image or just thinking before moving doesn't count against solve time.
        if currentMoveCount == 0 { startStopwatch() }
        currentMoveCount += 1
        isSolved = activeEngine.isSolved(tiles)

        let key = currentStatsKey
        let debugOverlayEnabled = settingsStore.debugOverlayEnabled

        if isSolved {
            stopCountdown()
            stopStopwatch()
            if isZenMode {
                statsStore.recordGamePlayed(for: key)
            } else if !debugOverlayEnabled {
                let result = statsStore.recordCompletion(for: key, moves: currentMoveCount, time: elapsedTime)
                isNewMovesRecord = result.isNewMovesRecord
                isNewBestTime = result.isNewBestTime
            }
        }

        if !isZenMode {
            let newlyCorrect = tiles.filter { $0.isCorrect }.count - correctBefore
            if newlyCorrect > 0 {
                let result = statsStore.recordStreakIncrement(for: key, trackRecord: !debugOverlayEnabled)
                if !isSolved { startCountdown() }
                if result.isNewRecord { isNewRecord = true }
            } else {
                statsStore.resetStreak(for: key)
                isNewRecord = false
                stopCountdown()
            }

            if !debugOverlayEnabled { achievementsStore.checkAchievements(using: statsStore) }
        }
        saveToUserDefaults()
    }

    func skipPreview() {
        previewSleepTask?.cancel()
        isPreviewing = false
    }

    /// Stops the countdown when the user quits mid-game; streak is preserved.
    func leaveGame() {
        stopCountdown()
        stopStopwatch()
        saveToUserDefaults()
    }
}

// MARK: - Configuration & current-size stats

extension GameSession {
    var difficultyLabel: String {
        switch gridSize {
        case 3: "Easy"
        case 4: "Medium"
        case 5: "Hard"
        case 6: "Expert"
        case 7: "Master"
        default: "Insane"
        }
    }

    var difficultyDisplayValue: String {
        useRandomSize ? "Random" : "\(difficultyLabel)  \(gridSize) × \(gridSize)"
    }

    var personalBestForCurrentSize: Int? { statsStore.personalBestMoves[currentStatsKey] }
    var personalBestTimeForCurrentSize: TimeInterval? { statsStore.personalBestTime[currentStatsKey] }
    var currentStreakForCurrentSize: Int { statsStore.currentStreak[currentStatsKey] ?? 0 }
    var allTimeHighStreakForCurrentSize: Int { statsStore.allTimeHighStreak[currentStatsKey] ?? 0 }

    /// Streaks only make sense in Classic mode (see `PuzzleStatusBarView`), so the menu's
    /// streak card always shows Classic's stats regardless of the currently selected mode.
    var classicBestMovesForCurrentSize: Int? {
        statsStore.personalBestMoves[StatsKey(gridSize: gridSize, gameMode: .classic)]
    }
    var classicStreakForCurrentSize: Int {
        statsStore.currentStreak[StatsKey(gridSize: gridSize, gameMode: .classic)] ?? 0
    }
    var classicBestStreakForCurrentSize: Int {
        statsStore.allTimeHighStreak[StatsKey(gridSize: gridSize, gameMode: .classic)] ?? 0
    }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize || useRandomSize else { return }
        useRandomSize = false
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        isSolved = false
        isNewRecord = false
        defaults.set(false, forKey: Keys.useRandomSize)
        defaults.set(gridSize, forKey: Keys.gridSize)
        defaults.removeObject(forKey: Keys.tiles)
        defaults.removeObject(forKey: Keys.sourceImage)
    }

    func setRandomSize() {
        useRandomSize = true
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        isSolved = false
        isNewRecord = false
        defaults.set(true, forKey: Keys.useRandomSize)
        defaults.removeObject(forKey: Keys.tiles)
        defaults.removeObject(forKey: Keys.sourceImage)
    }

    func setMediaSourceType(_ type: MediaSourceType) {
        guard type != mediaSourceType else { return }
        guard type != .numbers || selectedGameMode == .slide else { return }
        mediaSourceType = type
        defaults.set(type.rawValue, forKey: Keys.mediaSourceType)
    }

    func setGameMode(_ mode: GameMode) {
        guard mode.isAvailable, mode != selectedGameMode else { return }
        selectedGameMode = mode
        defaults.set(mode.rawValue, forKey: Keys.gameMode)

        // Numbers media mode is Slide-only for now; fall back if it's no longer valid.
        if mediaSourceType == .numbers && mode != .slide {
            setMediaSourceType(.random)
        }
    }

    func resetConfiguration() {
        setGridSize(3)
        setMediaSourceType(.random)
        useRandomSize = false
        defaults.set(false, forKey: Keys.useRandomSize)
    }
}

// MARK: - Persistence

extension GameSession {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let mediaSourceType = "puzzle.mediaSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let currentMoveCount = "puzzle.currentMoveCount"
        static let elapsedTime = "puzzle.elapsedTime"
        static let useRandomSize = "puzzle.useRandomSize"
        static let gameMode = "puzzle.gameMode"
    }
}

private extension GameSession {
    func saveToUserDefaults() {
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        defaults.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            defaults.set(jpegData, forKey: Keys.sourceImage)
        }

        defaults.set(gridSize, forKey: Keys.gridSize)
        defaults.set(useRandomSize, forKey: Keys.useRandomSize)
        defaults.set(mediaSourceType.rawValue, forKey: Keys.mediaSourceType)
        defaults.set(selectedGameMode.rawValue, forKey: Keys.gameMode)
        defaults.set(currentMoveCount, forKey: Keys.currentMoveCount)
        defaults.set(elapsedTime, forKey: Keys.elapsedTime)
    }

    func restoreFromUserDefaults() {
        let savedSize = defaults.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        useRandomSize = defaults.bool(forKey: Keys.useRandomSize)

        if let savedGameMode = defaults.string(forKey: Keys.gameMode).flatMap(GameMode.init(rawValue:)) {
            selectedGameMode = savedGameMode
        }

        if let rawSource = defaults.string(forKey: Keys.mediaSourceType),
           let savedSource = MediaSourceType(rawValue: rawSource) {
            mediaSourceType = savedSource
        }
        // Numbers media mode is Slide-only for now.
        if mediaSourceType == .numbers && selectedGameMode != .slide {
            mediaSourceType = .random
        }

        guard
            let tilesData = defaults.data(forKey: Keys.tiles),
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData)
        else { return }

        guard restoredTiles.count == gridSize * gridSize else { return }

        if mediaSourceType == .numbers {
            tiles = restoredTiles
        } else {
            guard
                let imageData = defaults.data(forKey: Keys.sourceImage),
                let restoredImage = cgImage(fromJPEG: imageData)
            else { return }

            tiles = restoredTiles
            sourceImage = restoredImage
            let slicer = ImageSlicer()
            croppedSourceImage = slicer.centerCrop(restoredImage)
            let slices = slicer.slice(restoredImage, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })
        }

        isSolved = activeEngine.isSolved(tiles)
        currentMoveCount = defaults.integer(forKey: Keys.currentMoveCount)
        elapsedTime = defaults.double(forKey: Keys.elapsedTime)
        if !isSolved && currentStreakForCurrentSize > 0 { startCountdown() }
        // Resume the stopwatch only if it had actually started (i.e. a move was already made);
        // otherwise it should still wait for the first move, same as a fresh game.
        if !isSolved && currentMoveCount > 0 { startStopwatch() }
    }

    func jpeg(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }

    func cgImage(fromJPEG data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
