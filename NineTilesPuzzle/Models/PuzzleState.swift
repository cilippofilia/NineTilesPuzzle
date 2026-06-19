//
//  PuzzleState.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
@Observable
final class PuzzleState {
    /// Grid size and move-mechanic differ enough per mode (e.g. Slide needs far more moves
    /// than Classic to solve the same grid) that per-size stats must also be split by mode.
    struct StatsKey: Hashable {
        let gridSize: Int
        let gameMode: GameMode
    }

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
    var currentStreak: [StatsKey: Int] = [:]
    var allTimeHighStreak: [StatsKey: Int] = [:]
    var isNewRecord: Bool = false
    var currentMoveCount: Int = 0
    var personalBestMoves: [StatsKey: Int] = [:]
    var isNewMovesRecord: Bool = false
    var gamesPlayed: [StatsKey: Int] = [:]
    var elapsedTime: TimeInterval = 0
    var personalBestTime: [StatsKey: TimeInterval] = [:]
    var isNewBestTime: Bool = false
    var achievements: [Achievement] = []
    var newlyUnlockedAchievement: Achievement? = nil
    var error: Error?
    var previewDuration: Double = 3
    var streakCountdownDuration: Double = 30
    var hapticsEnabled: Bool = true
    var debugOverlayEnabled: Bool = false
    var selectedGameMode: GameMode = .classic

    private(set) var timerRemaining: Double = 30
    private(set) var isTimerRunning = false
    private(set) var didBreakStreak = false

    private var countdownTask: Task<Void, Never>?
    private var stopwatchTask: Task<Void, Never>?

    /// Zen mode tracks nothing but the number of games played: no streaks, no personal
    /// bests, no achievements — just an uninterrupted, judgment-free puzzle loop.
    var isZenMode: Bool { selectedGameMode == .zen }

    private var activeEngine: any GameEngine {
        switch selectedGameMode {
        case .slide:
            return slideEngine
        default:
            return classicEngine
        }
    }

    init() {
        restoreFromUserDefaults()
        loadAchievements()
        checkAchievements()
        Task { await refreshAchievementsFromRemote() }
    }

    func startCountdown() {
        guard streakCountdownDuration > 0 else { return }
        stopCountdown()
        timerRemaining = streakCountdownDuration
        isTimerRunning = true
        let end = Date.now.addingTimeInterval(streakCountdownDuration)
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    currentStreak[currentStatsKey] = 0
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
        timerRemaining = streakCountdownDuration
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

            if isRemote && previewDuration > 0 {
                isPreviewing = true
                previewSleepTask = Task { try? await Task.sleep(for: .seconds(previewDuration)) }
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

        if isSolved {
            stopCountdown()
            stopStopwatch()
            if isZenMode {
                let key = StatsKey(gridSize: gridSize, gameMode: selectedGameMode)
                gamesPlayed[key, default: 0] += 1
                UserDefaults.standard.set(gamesPlayed[key]!, forKey: Keys.gamesPlayed(for: gridSize, mode: selectedGameMode))
            } else if !debugOverlayEnabled {
                let key = StatsKey(gridSize: gridSize, gameMode: selectedGameMode)
                let existing = personalBestMoves[key]
                if existing == nil || currentMoveCount < existing! {
                    personalBestMoves[key] = currentMoveCount
                    isNewMovesRecord = true
                    UserDefaults.standard.set(currentMoveCount, forKey: Keys.personalBest(for: gridSize, mode: selectedGameMode))
                }
                let existingTime = personalBestTime[key]
                if existingTime == nil || elapsedTime < existingTime! {
                    personalBestTime[key] = elapsedTime
                    isNewBestTime = true
                    UserDefaults.standard.set(elapsedTime, forKey: Keys.personalBestTime(for: gridSize, mode: selectedGameMode))
                }
                gamesPlayed[key, default: 0] += 1
                UserDefaults.standard.set(gamesPlayed[key]!, forKey: Keys.gamesPlayed(for: gridSize, mode: selectedGameMode))
            }
        }

        if !isZenMode {
            let key = currentStatsKey
            let newlyCorrect = tiles.filter { $0.isCorrect }.count - correctBefore
            if newlyCorrect > 0 {
                let streak = currentStreak[key, default: 0] + 1
                currentStreak[key] = streak
                if !isSolved { startCountdown() }
                if !debugOverlayEnabled && streak > (allTimeHighStreak[key] ?? 0) {
                    allTimeHighStreak[key] = streak
                    isNewRecord = true
                    UserDefaults.standard.set(streak, forKey: Keys.allTimeHighStreak(for: key.gridSize, mode: key.gameMode))
                }
            } else {
                currentStreak[key] = 0
                isNewRecord = false
                stopCountdown()
            }

            if !debugOverlayEnabled { checkAchievements() }
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

// MARK: - Persistence

extension PuzzleState {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let mediaSourceType = "puzzle.mediaSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let previewDuration = "puzzle.previewDuration"
        static let streakCountdownDuration = "puzzle.streakCountdownDuration"
        static let currentMoveCount = "puzzle.currentMoveCount"
        static let elapsedTime = "puzzle.elapsedTime"
        static let useRandomSize = "puzzle.useRandomSize"
        static let hapticsEnabled = "puzzle.hapticsEnabled"
        static let debugOverlayEnabled = "puzzle.debugOverlayEnabled"
        static let gameMode = "puzzle.gameMode"

        static func personalBest(for size: Int, mode: GameMode) -> String { "puzzle.personalBest.\(mode.rawValue).\(size)" }
        static func personalBestTime(for size: Int, mode: GameMode) -> String { "puzzle.personalBestTime.\(mode.rawValue).\(size)" }
        static func gamesPlayed(for size: Int, mode: GameMode) -> String { "puzzle.gamesPlayed.\(mode.rawValue).\(size)" }
        static func currentStreak(for size: Int, mode: GameMode) -> String { "puzzle.currentStreak.\(mode.rawValue).\(size)" }
        static func allTimeHighStreak(for size: Int, mode: GameMode) -> String { "puzzle.allTimeHighStreak.\(mode.rawValue).\(size)" }
        static func achievement(id: String) -> String { "puzzle.achievement.\(id)" }
    }
}

private extension PuzzleState {
    func saveToUserDefaults() {
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        UserDefaults.standard.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            UserDefaults.standard.set(jpegData, forKey: Keys.sourceImage)
        }

        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.set(useRandomSize, forKey: Keys.useRandomSize)
        UserDefaults.standard.set(mediaSourceType.rawValue, forKey: Keys.mediaSourceType)
        UserDefaults.standard.set(previewDuration, forKey: Keys.previewDuration)
        UserDefaults.standard.set(streakCountdownDuration, forKey: Keys.streakCountdownDuration)
        UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        UserDefaults.standard.set(debugOverlayEnabled, forKey: Keys.debugOverlayEnabled)
        UserDefaults.standard.set(selectedGameMode.rawValue, forKey: Keys.gameMode)
        UserDefaults.standard.set(currentMoveCount, forKey: Keys.currentMoveCount)
        UserDefaults.standard.set(elapsedTime, forKey: Keys.elapsedTime)
        for (key, value) in currentStreak {
            UserDefaults.standard.set(value, forKey: Keys.currentStreak(for: key.gridSize, mode: key.gameMode))
        }
    }

    func restoreFromUserDefaults() {
        let savedSize = UserDefaults.standard.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        useRandomSize = UserDefaults.standard.bool(forKey: Keys.useRandomSize)

        if UserDefaults.standard.object(forKey: Keys.previewDuration) != nil {
            previewDuration = UserDefaults.standard.double(forKey: Keys.previewDuration)
        }
        if UserDefaults.standard.object(forKey: Keys.streakCountdownDuration) != nil {
            streakCountdownDuration = UserDefaults.standard.double(forKey: Keys.streakCountdownDuration)
        }
        if UserDefaults.standard.object(forKey: Keys.hapticsEnabled) != nil {
            hapticsEnabled = UserDefaults.standard.bool(forKey: Keys.hapticsEnabled)
        }
        if UserDefaults.standard.object(forKey: Keys.debugOverlayEnabled) != nil {
            debugOverlayEnabled = UserDefaults.standard.bool(forKey: Keys.debugOverlayEnabled)
        }
        if let savedGameMode = UserDefaults.standard.string(forKey: Keys.gameMode).flatMap(GameMode.init(rawValue:)) {
            selectedGameMode = savedGameMode
        }

        if let rawSource = UserDefaults.standard.string(forKey: Keys.mediaSourceType),
           let savedSource = MediaSourceType(rawValue: rawSource) {
            mediaSourceType = savedSource
        }
        // Numbers media mode is Slide-only for now.
        if mediaSourceType == .numbers && selectedGameMode != .slide {
            mediaSourceType = .random
        }

        // Restored unconditionally (not gated behind the tiles guard below) since these
        // stats persist independently of whatever game happened to be in progress.
        personalBestMoves = [:]
        personalBestTime = [:]
        gamesPlayed = [:]
        currentStreak = [:]
        allTimeHighStreak = [:]
        for mode in GameMode.allCases {
            for size in 3...8 {
                let key = StatsKey(gridSize: size, gameMode: mode)
                let moves = UserDefaults.standard.integer(forKey: Keys.personalBest(for: size, mode: mode))
                if moves > 0 { personalBestMoves[key] = moves }
                let time = UserDefaults.standard.double(forKey: Keys.personalBestTime(for: size, mode: mode))
                if time > 0 { personalBestTime[key] = time }
                let played = UserDefaults.standard.integer(forKey: Keys.gamesPlayed(for: size, mode: mode))
                if played > 0 { gamesPlayed[key] = played }
                let streak = UserDefaults.standard.integer(forKey: Keys.currentStreak(for: size, mode: mode))
                if streak > 0 { currentStreak[key] = streak }
                let bestStreak = UserDefaults.standard.integer(forKey: Keys.allTimeHighStreak(for: size, mode: mode))
                if bestStreak > 0 { allTimeHighStreak[key] = bestStreak }
            }
        }

        guard
            let tilesData = UserDefaults.standard.data(forKey: Keys.tiles),
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData)
        else { return }

        guard restoredTiles.count == gridSize * gridSize else { return }

        if mediaSourceType == .numbers {
            tiles = restoredTiles
        } else {
            guard
                let imageData = UserDefaults.standard.data(forKey: Keys.sourceImage),
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
        currentMoveCount = UserDefaults.standard.integer(forKey: Keys.currentMoveCount)
        elapsedTime = UserDefaults.standard.double(forKey: Keys.elapsedTime)
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
