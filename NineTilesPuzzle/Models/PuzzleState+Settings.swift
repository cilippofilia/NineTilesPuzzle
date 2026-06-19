//
//  PuzzleState+Settings.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

extension PuzzleState {
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

    var previewDurationLabel: String {
        previewDuration == 0 ? "Off" : previewDuration < 60 ? "\(Int(previewDuration))s" : "\(Int(previewDuration / 60))m"
    }

    var streakCountdownLabel: String {
        streakCountdownDuration == 0 ? "Off" : streakCountdownDuration < 60 ? "\(Int(streakCountdownDuration))s" : "\(Int(streakCountdownDuration / 60))m"
    }

    private var currentStatsKey: StatsKey { StatsKey(gridSize: gridSize, gameMode: selectedGameMode) }

    var personalBestForCurrentSize: Int? { personalBestMoves[currentStatsKey] }
    var personalBestTimeForCurrentSize: TimeInterval? { personalBestTime[currentStatsKey] }

    /// Streaks only make sense in Classic mode (see `PuzzleStatusBarView`), so the menu's
    /// streak card always shows Classic's best moves regardless of the currently selected mode.
    var classicBestMovesForCurrentSize: Int? {
        personalBestMoves[StatsKey(gridSize: gridSize, gameMode: .classic)]
    }

    /// Total games played at `size`, summed across every game mode.
    func gamesPlayedCount(forSize size: Int) -> Int {
        gamesPlayed.filter { $0.key.gridSize == size }.values.reduce(0, +)
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
        UserDefaults.standard.set(false, forKey: Keys.useRandomSize)
        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.removeObject(forKey: Keys.tiles)
        UserDefaults.standard.removeObject(forKey: Keys.sourceImage)
    }

    func setRandomSize() {
        useRandomSize = true
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        isSolved = false
        isNewRecord = false
        UserDefaults.standard.set(true, forKey: Keys.useRandomSize)
        UserDefaults.standard.removeObject(forKey: Keys.tiles)
        UserDefaults.standard.removeObject(forKey: Keys.sourceImage)
    }

    func setMediaSourceType(_ type: MediaSourceType) {
        guard type != mediaSourceType else { return }
        guard type != .numbers || selectedGameMode == .slide else { return }
        mediaSourceType = type
        UserDefaults.standard.set(type.rawValue, forKey: Keys.mediaSourceType)
    }

    func setPreviewDuration(_ duration: Double) {
        guard duration != previewDuration else { return }
        previewDuration = duration
        UserDefaults.standard.set(duration, forKey: Keys.previewDuration)
    }

    func setHapticsEnabled(_ value: Bool) {
        hapticsEnabled = value
        UserDefaults.standard.set(value, forKey: Keys.hapticsEnabled)
    }

    func setDebugOverlayEnabled(_ value: Bool) {
        debugOverlayEnabled = value
        UserDefaults.standard.set(value, forKey: Keys.debugOverlayEnabled)
    }

    func setGameMode(_ mode: GameMode) {
        guard mode.isAvailable, mode != selectedGameMode else { return }
        selectedGameMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.gameMode)

        // Numbers media mode is Slide-only for now; fall back if it's no longer valid.
        if mediaSourceType == .numbers && mode != .slide {
            setMediaSourceType(.random)
        }
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
        currentMoveCount = 0
        personalBestMoves = [:]
        isNewMovesRecord = false
        gamesPlayed = [:]
        elapsedTime = 0
        personalBestTime = [:]
        isNewBestTime = false
        stopCountdown()
        stopStopwatch()
        UserDefaults.standard.removeObject(forKey: Keys.currentStreak)
        UserDefaults.standard.removeObject(forKey: Keys.allTimeHighStreak)
        UserDefaults.standard.removeObject(forKey: Keys.currentMoveCount)
        UserDefaults.standard.removeObject(forKey: Keys.elapsedTime)
        for mode in GameMode.allCases {
            for size in 3...8 {
                UserDefaults.standard.removeObject(forKey: Keys.personalBest(for: size, mode: mode))
                UserDefaults.standard.removeObject(forKey: Keys.personalBestTime(for: size, mode: mode))
                UserDefaults.standard.removeObject(forKey: Keys.gamesPlayed(for: size, mode: mode))
            }
        }
    }

    func resetSettings() {
        setGridSize(3)
        setMediaSourceType(.random)
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
        setHapticsEnabled(true)
        useRandomSize = false
        UserDefaults.standard.set(false, forKey: Keys.useRandomSize)
    }
}
