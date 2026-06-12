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
    private let puzzleEngine = PuzzleEngine()
    private var previewSleepTask: Task<Void, Never>?

    var gridSize: Int = 3
    var useRandomSize: Bool = false
    var imageSourceType: ImageSourceType = .random
    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    var isLoading = false
    var isPreviewing = false
    var isSolved = false
    var currentStreak: Int = 0
    var allTimeHighStreak: Int = 0
    var isNewRecord: Bool = false
    var currentMoveCount: Int = 0
    var personalBestMoves: [Int: Int] = [:]
    var isNewMovesRecord: Bool = false
    var gamesPlayed: [Int: Int] = [:]
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
                    currentStreak = 0
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

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state.
    func startNewGame() async {
        if useRandomSize { gridSize = Int.random(in: 3...8) }
        tiles = []
        tileImages = [:]
        sourceImage = nil
        isLoading = true
        isSolved = false
        isNewRecord = false
        currentMoveCount = 0
        isNewMovesRecord = false
        error = nil

        do {
            let source: any ImageSource = switch imageSourceType {
            case .random: RemoteImageSource()
            case .local: PhotoLibraryImageSource()
            case .mixed: Bool.random() ? RemoteImageSource() : PhotoLibraryImageSource()
            }
            let isRemote = source is RemoteImageSource
            let image = try await ImageService(primarySource: source).loadImage()
            sourceImage = image

            let slices = ImageSlicer().slice(image, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            let initial = (0..<gridSize * gridSize).map {
                TileModel(id: $0, currentIndex: $0, isLocked: false)
            }

            isLoading = false

            if isRemote && previewDuration > 0 {
                isPreviewing = true
                previewSleepTask = Task { try? await Task.sleep(for: .seconds(previewDuration)) }
                await previewSleepTask?.value
                previewSleepTask = nil
                isPreviewing = false
            }

            tiles = puzzleEngine.shuffle(initial)
            if currentStreak > 0 { startCountdown() }
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

        currentMoveCount += 1

        let lockedBefore = tiles.filter { $0.isLocked }.count
        puzzleEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        isSolved = puzzleEngine.isSolved(tiles)

        if isSolved {
            stopCountdown()
            if !debugOverlayEnabled {
                let existing = personalBestMoves[gridSize]
                if existing == nil || currentMoveCount < existing! {
                    personalBestMoves[gridSize] = currentMoveCount
                    isNewMovesRecord = true
                    UserDefaults.standard.set(currentMoveCount, forKey: Keys.personalBest(for: gridSize))
                }
                gamesPlayed[gridSize, default: 0] += 1
                UserDefaults.standard.set(gamesPlayed[gridSize]!, forKey: Keys.gamesPlayed(for: gridSize))
            }
        }

        let newlyLocked = tiles.filter { $0.isLocked }.count - lockedBefore
        if newlyLocked > 0 {
            currentStreak += 1
            if !isSolved { startCountdown() }
            if !debugOverlayEnabled && currentStreak > allTimeHighStreak {
                allTimeHighStreak = currentStreak
                isNewRecord = true
                UserDefaults.standard.set(allTimeHighStreak, forKey: Keys.allTimeHighStreak)
            }
        } else {
            currentStreak = 0
            isNewRecord = false
            stopCountdown()
        }

        if !debugOverlayEnabled { checkAchievements() }
        saveToUserDefaults()
    }

    func skipPreview() {
        previewSleepTask?.cancel()
        isPreviewing = false
    }

    /// Stops the countdown when the user quits mid-game; streak is preserved.
    func leaveGame() {
        stopCountdown()
        saveToUserDefaults()
    }
}

// MARK: - Persistence

extension PuzzleState {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let imageSourceType = "puzzle.imageSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let currentStreak = "puzzle.currentStreak"
        static let allTimeHighStreak = "puzzle.allTimeHighStreak"
        static let previewDuration = "puzzle.previewDuration"
        static let streakCountdownDuration = "puzzle.streakCountdownDuration"
        static let currentMoveCount = "puzzle.currentMoveCount"
        static let useRandomSize = "puzzle.useRandomSize"
        static let hapticsEnabled = "puzzle.hapticsEnabled"
        static let debugOverlayEnabled = "puzzle.debugOverlayEnabled"
        static let gameMode = "puzzle.gameMode"

        static func personalBest(for size: Int) -> String { "puzzle.personalBest.\(size)" }
        static func gamesPlayed(for size: Int) -> String { "puzzle.gamesPlayed.\(size)" }
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
        UserDefaults.standard.set(imageSourceType.rawValue, forKey: Keys.imageSourceType)
        UserDefaults.standard.set(previewDuration, forKey: Keys.previewDuration)
        UserDefaults.standard.set(streakCountdownDuration, forKey: Keys.streakCountdownDuration)
        UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        UserDefaults.standard.set(debugOverlayEnabled, forKey: Keys.debugOverlayEnabled)
        UserDefaults.standard.set(selectedGameMode.rawValue, forKey: Keys.gameMode)
        UserDefaults.standard.set(currentStreak, forKey: Keys.currentStreak)
        UserDefaults.standard.set(currentMoveCount, forKey: Keys.currentMoveCount)
    }

    func restoreFromUserDefaults() {
        let savedSize = UserDefaults.standard.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        useRandomSize = UserDefaults.standard.bool(forKey: Keys.useRandomSize)
        allTimeHighStreak = UserDefaults.standard.integer(forKey: Keys.allTimeHighStreak)

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

        if let rawSource = UserDefaults.standard.string(forKey: Keys.imageSourceType),
           let savedSource = ImageSourceType(rawValue: rawSource) {
            imageSourceType = savedSource
        }

        guard
            let tilesData = UserDefaults.standard.data(forKey: Keys.tiles),
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData),
            let imageData = UserDefaults.standard.data(forKey: Keys.sourceImage),
            let restoredImage = cgImage(fromJPEG: imageData)
        else { return }

        guard restoredTiles.count == gridSize * gridSize else { return }

        tiles = restoredTiles
        sourceImage = restoredImage
        let slices = ImageSlicer().slice(restoredImage, into: gridSize * gridSize)
        tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })
        isSolved = puzzleEngine.isSolved(tiles)
        currentStreak = UserDefaults.standard.integer(forKey: Keys.currentStreak)
        currentMoveCount = UserDefaults.standard.integer(forKey: Keys.currentMoveCount)
        personalBestMoves = (3...8).reduce(into: [:]) { dict, size in
            let value = UserDefaults.standard.integer(forKey: Keys.personalBest(for: size))
            if value > 0 { dict[size] = value }
        }
        gamesPlayed = (3...8).reduce(into: [:]) { dict, size in
            let value = UserDefaults.standard.integer(forKey: Keys.gamesPlayed(for: size))
            if value > 0 { dict[size] = value }
        }
        if !isSolved && currentStreak > 0 { startCountdown() }
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
