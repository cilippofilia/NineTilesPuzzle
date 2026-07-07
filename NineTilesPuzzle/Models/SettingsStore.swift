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
    /// Seconds on the Quick Snap capture countdown before the frame is auto-snapped.
    var quickSnapDuration: Double = 3
    /// Which camera Quick Snap opens with, remembered across sessions. `false` is the back camera.
    var quickSnapUsesFrontCamera: Bool = false
    var hapticsEnabled: Bool = true
    var debugOverlayEnabled: Bool = false
    /// Debug-tunable power-up values, surfaced in Settings' Dev Tools section so the
    /// defaults in `PowerUpRules` can be tried out and adjusted on device before locking
    /// them in.
    var peekDuration: Double = PowerUpRules.peekDuration
    var streakMilestoneInterval: Int = PowerUpRules.streakMilestoneInterval
    /// When true, every `GameSession.use...PowerUp()` method skips `PowerUpStore.consume`
    /// entirely — power-ups can be spammed for testing without touching real inventory.
    var debugInfinitePowerUps: Bool = false

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

    var quickSnapDurationLabel: String {
        "\(Int(quickSnapDuration))s"
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

    func setQuickSnapDuration(_ duration: Double) {
        guard duration != quickSnapDuration else { return }
        quickSnapDuration = duration
        defaults.set(duration, forKey: Keys.quickSnapDuration)
    }

    func setQuickSnapUsesFrontCamera(_ value: Bool) {
        guard value != quickSnapUsesFrontCamera else { return }
        quickSnapUsesFrontCamera = value
        defaults.set(value, forKey: Keys.quickSnapUsesFrontCamera)
    }

    func setHapticsEnabled(_ value: Bool) {
        hapticsEnabled = value
        defaults.set(value, forKey: Keys.hapticsEnabled)
    }

    func setDebugOverlayEnabled(_ value: Bool) {
        debugOverlayEnabled = value
        defaults.set(value, forKey: Keys.debugOverlayEnabled)
    }

    func setPeekDuration(_ duration: Double) {
        guard duration != peekDuration else { return }
        peekDuration = duration
        defaults.set(duration, forKey: Keys.peekDuration)
    }

    func setStreakMilestoneInterval(_ interval: Int) {
        guard interval != streakMilestoneInterval else { return }
        streakMilestoneInterval = interval
        defaults.set(interval, forKey: Keys.streakMilestoneInterval)
    }

    func setDebugInfinitePowerUps(_ value: Bool) {
        debugInfinitePowerUps = value
        defaults.set(value, forKey: Keys.debugInfinitePowerUps)
    }

    func resetSettings() {
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
        setQuickSnapDuration(3)
        setQuickSnapUsesFrontCamera(false)
        setHapticsEnabled(true)
        setPeekDuration(PowerUpRules.peekDuration)
        setStreakMilestoneInterval(PowerUpRules.streakMilestoneInterval)
    }
}

private extension SettingsStore {
    enum Keys {
        static let previewDuration = "puzzle.previewDuration"
        static let streakCountdownDuration = "puzzle.streakCountdownDuration"
        static let quickSnapDuration = "puzzle.quickSnapDuration"
        static let quickSnapUsesFrontCamera = "puzzle.quickSnapUsesFrontCamera"
        static let hapticsEnabled = "puzzle.hapticsEnabled"
        static let debugOverlayEnabled = "puzzle.debugOverlayEnabled"
        static let peekDuration = "puzzle.peekDuration"
        static let streakMilestoneInterval = "puzzle.streakMilestoneInterval"
        static let debugInfinitePowerUps = "puzzle.debugInfinitePowerUps"
    }

    func restoreFromUserDefaults() {
        if defaults.object(forKey: Keys.previewDuration) != nil {
            previewDuration = defaults.double(forKey: Keys.previewDuration)
        }
        if defaults.object(forKey: Keys.streakCountdownDuration) != nil {
            streakCountdownDuration = defaults.double(forKey: Keys.streakCountdownDuration)
        }
        if defaults.object(forKey: Keys.quickSnapDuration) != nil {
            quickSnapDuration = defaults.double(forKey: Keys.quickSnapDuration)
        }
        if defaults.object(forKey: Keys.quickSnapUsesFrontCamera) != nil {
            quickSnapUsesFrontCamera = defaults.bool(forKey: Keys.quickSnapUsesFrontCamera)
        }
        if defaults.object(forKey: Keys.hapticsEnabled) != nil {
            hapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        }
        if defaults.object(forKey: Keys.debugOverlayEnabled) != nil {
            debugOverlayEnabled = defaults.bool(forKey: Keys.debugOverlayEnabled)
        }
        if defaults.object(forKey: Keys.peekDuration) != nil {
            peekDuration = defaults.double(forKey: Keys.peekDuration)
        }
        if defaults.object(forKey: Keys.streakMilestoneInterval) != nil {
            streakMilestoneInterval = defaults.integer(forKey: Keys.streakMilestoneInterval)
        }
        if defaults.object(forKey: Keys.debugInfinitePowerUps) != nil {
            debugInfinitePowerUps = defaults.bool(forKey: Keys.debugInfinitePowerUps)
        }
    }
}
