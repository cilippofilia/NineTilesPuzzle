//
//  SettingsStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

/// App-wide preferences that aren't tied to "which game is being played" — those
/// (grid size, media source, game mode) live on `GameSession` instead, since changing
/// them needs to synchronously clear the in-progress board.
@MainActor
@Observable
final class SettingsStore {
    var previewDuration: Double = 3
    var streakCountdownDuration: Double = 30
    var hapticsEnabled: Bool = true
    var debugOverlayEnabled: Bool = false

    init() {
        restoreFromUserDefaults()
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
        UserDefaults.standard.set(duration, forKey: Keys.streakCountdownDuration)
    }

    func setHapticsEnabled(_ value: Bool) {
        hapticsEnabled = value
        UserDefaults.standard.set(value, forKey: Keys.hapticsEnabled)
    }

    func setDebugOverlayEnabled(_ value: Bool) {
        debugOverlayEnabled = value
        UserDefaults.standard.set(value, forKey: Keys.debugOverlayEnabled)
    }

    func resetSettings() {
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
        setHapticsEnabled(true)
    }
}

private extension SettingsStore {
    enum Keys {
        static let previewDuration = "puzzle.previewDuration"
        static let streakCountdownDuration = "puzzle.streakCountdownDuration"
        static let hapticsEnabled = "puzzle.hapticsEnabled"
        static let debugOverlayEnabled = "puzzle.debugOverlayEnabled"
    }

    func restoreFromUserDefaults() {
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
    }
}
