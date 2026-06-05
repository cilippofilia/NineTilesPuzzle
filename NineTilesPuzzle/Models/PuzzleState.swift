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
    var error: Error?
    var previewDuration: Double = 3
    var streakCountdownDuration: Double = 30

    private(set) var timerRemaining: Double = 30
    private(set) var isTimerRunning = false
    private(set) var didBreakStreak = false

    private var countdownTask: Task<Void, Never>?

    init() {
        restoreFromUserDefaults()
    }

    private func startCountdown() {
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

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        timerRemaining = streakCountdownDuration
        isTimerRunning = false
    }

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state.
    func startNewGame() async {
        tiles = []
        tileImages = [:]
        sourceImage = nil
        isLoading = true
        isSolved = false
        isNewRecord = false
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

    func setImageSourceType(_ type: ImageSourceType) {
        guard type != imageSourceType else { return }
        imageSourceType = type
        UserDefaults.standard.set(type.rawValue, forKey: Keys.imageSourceType)
    }

    var previewDurationLabel: String {
        previewDuration == 0 ? "Off" : previewDuration < 60 ? "\(Int(previewDuration))s" : "\(Int(previewDuration / 60))m"
    }

    var streakCountdownLabel: String {
        streakCountdownDuration == 0 ? "Off" : streakCountdownDuration < 60 ? "\(Int(streakCountdownDuration))s" : "\(Int(streakCountdownDuration / 60))m"
    }

    func setPreviewDuration(_ duration: Double) {
        guard duration != previewDuration else { return }
        previewDuration = duration
        UserDefaults.standard.set(duration, forKey: Keys.previewDuration)
    }

    func setStreakCountdownDuration(_ duration: Double) {
        guard duration != streakCountdownDuration else { return }
        streakCountdownDuration = duration
        if duration == 0 { stopCountdown() }
        UserDefaults.standard.set(duration, forKey: Keys.streakCountdownDuration)
    }

    func resetStats() {
        currentStreak = 0
        allTimeHighStreak = 0
        isNewRecord = false
        stopCountdown()
        UserDefaults.standard.removeObject(forKey: Keys.currentStreak)
        UserDefaults.standard.removeObject(forKey: Keys.allTimeHighStreak)
    }

    func resetSettings() {
        setGridSize(3)
        setImageSourceType(.random)
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
    }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize else { return }
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
        isSolved = false
        isNewRecord = false
        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.removeObject(forKey: Keys.tiles)
        UserDefaults.standard.removeObject(forKey: Keys.sourceImage)
    }

    /// Attempts to swap the tiles at `sourceIndex` and `targetIndex`; no-ops if either is locked.
    func swapTiles(from sourceIndex: Int, to targetIndex: Int) {
        guard
            let source = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let target = tiles.first(where: { $0.currentIndex == targetIndex }),
            !source.isLocked,
            !target.isLocked
        else { return }

        let lockedBefore = tiles.filter { $0.isLocked }.count
        puzzleEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        isSolved = puzzleEngine.isSolved(tiles)

        if isSolved { stopCountdown() }

        let newlyLocked = tiles.filter { $0.isLocked }.count - lockedBefore
        if newlyLocked > 0 {
            currentStreak += 1
            if !isSolved { startCountdown() }
            if currentStreak > allTimeHighStreak {
                allTimeHighStreak = currentStreak
                isNewRecord = true
                UserDefaults.standard.set(allTimeHighStreak, forKey: Keys.allTimeHighStreak)
            }
        } else {
            currentStreak = 0
            isNewRecord = false
            stopCountdown()
        }

        saveToUserDefaults()
    }

    func skipPreview() {
        previewSleepTask?.cancel()
        isPreviewing = false
    }

    /// Stops the countdown and resets the streak when the user quits mid-game.
    func leaveGame() {
        stopCountdown()
        currentStreak = 0
        isNewRecord = false
        saveToUserDefaults()
    }
}

// MARK: - Persistence

private extension PuzzleState {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let imageSourceType = "puzzle.imageSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let currentStreak = "puzzle.currentStreak"
        static let allTimeHighStreak = "puzzle.allTimeHighStreak"
        static let previewDuration = "puzzle.previewDuration"
        static let streakCountdownDuration = "puzzle.streakCountdownDuration"
    }

    func saveToUserDefaults() {
        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.set(imageSourceType.rawValue, forKey: Keys.imageSourceType)
        UserDefaults.standard.set(previewDuration, forKey: Keys.previewDuration)
        UserDefaults.standard.set(streakCountdownDuration, forKey: Keys.streakCountdownDuration)
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        UserDefaults.standard.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            UserDefaults.standard.set(jpegData, forKey: Keys.sourceImage)
        }
        UserDefaults.standard.set(currentStreak, forKey: Keys.currentStreak)
    }

    func restoreFromUserDefaults() {
        let savedSize = UserDefaults.standard.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        allTimeHighStreak = UserDefaults.standard.integer(forKey: Keys.allTimeHighStreak)

        if UserDefaults.standard.object(forKey: Keys.previewDuration) != nil {
            previewDuration = UserDefaults.standard.double(forKey: Keys.previewDuration)
        }
        if UserDefaults.standard.object(forKey: Keys.streakCountdownDuration) != nil {
            streakCountdownDuration = UserDefaults.standard.double(forKey: Keys.streakCountdownDuration)
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
