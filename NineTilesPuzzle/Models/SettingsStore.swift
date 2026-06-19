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
    private let defaults: PersistenceStore

    var previewDuration: Double = 3
    var streakCountdownDuration: Double = 30
    var hapticsEnabled: Bool = true
    var debugOverlayEnabled: Bool = false

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
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
        defaults.set(duration, forKey: Keys.previewDuration)
    }

    func setStreakCountdownDuration(_ duration: Double) {
        guard duration != streakCountdownDuration else { return }
        streakCountdownDuration = duration
        defaults.set(duration, forKey: Keys.streakCountdownDuration)
    }

    func setHapticsEnabled(_ value: Bool) {
        hapticsEnabled = value
        defaults.set(value, forKey: Keys.hapticsEnabled)
    }

    func setDebugOverlayEnabled(_ value: Bool) {
        debugOverlayEnabled = value
        defaults.set(value, forKey: Keys.debugOverlayEnabled)
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
        if defaults.object(forKey: Keys.previewDuration) != nil {
            previewDuration = defaults.double(forKey: Keys.previewDuration)
        }
        if defaults.object(forKey: Keys.streakCountdownDuration) != nil {
            streakCountdownDuration = defaults.double(forKey: Keys.streakCountdownDuration)
        }
        if defaults.object(forKey: Keys.hapticsEnabled) != nil {
            hapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        }
        if defaults.object(forKey: Keys.debugOverlayEnabled) != nil {
            debugOverlayEnabled = defaults.bool(forKey: Keys.debugOverlayEnabled)
        }
    }
}
