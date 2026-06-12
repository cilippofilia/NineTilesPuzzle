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

    var personalBestForCurrentSize: Int? { personalBestMoves[gridSize] }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize || useRandomSize else { return }
        useRandomSize = false
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
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
        isSolved = false
        isNewRecord = false
        UserDefaults.standard.set(true, forKey: Keys.useRandomSize)
        UserDefaults.standard.removeObject(forKey: Keys.tiles)
        UserDefaults.standard.removeObject(forKey: Keys.sourceImage)
    }

    func setImageSourceType(_ type: ImageSourceType) {
        guard type != imageSourceType else { return }
        imageSourceType = type
        UserDefaults.standard.set(type.rawValue, forKey: Keys.imageSourceType)
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
        stopCountdown()
        UserDefaults.standard.removeObject(forKey: Keys.currentStreak)
        UserDefaults.standard.removeObject(forKey: Keys.allTimeHighStreak)
        UserDefaults.standard.removeObject(forKey: Keys.currentMoveCount)
        (3...8).forEach {
            UserDefaults.standard.removeObject(forKey: Keys.personalBest(for: $0))
            UserDefaults.standard.removeObject(forKey: Keys.gamesPlayed(for: $0))
        }
    }

    func resetSettings() {
        setGridSize(3)
        setImageSourceType(.random)
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
        setHapticsEnabled(true)
        useRandomSize = false
        UserDefaults.standard.set(false, forKey: Keys.useRandomSize)
    }
}
