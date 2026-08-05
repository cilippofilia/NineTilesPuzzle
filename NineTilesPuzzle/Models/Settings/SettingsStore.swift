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
    var feedbackIntensity: FeedbackIntensity = .standard
    /// Master switch for the power-ups system (Peek, Hint, Streak Freeze, Re-shuffle,
    /// Auto-place). Still being tuned, so it ships hidden — there's no user-facing control,
    /// only the toggle in Settings' Dev Tools section.
    var powerUpsEnabled: Bool = false
    var debugOverlayEnabled: Bool = false
    /// Debug-tunable power-up values, surfaced in Settings' Dev Tools section so the
    /// defaults in `PowerUpRules` can be tried out and adjusted on device before locking
    /// them in.
    var peekDuration: Double = PowerUpRules.peekDuration
    var streakMilestoneInterval: Int = PowerUpRules.streakMilestoneInterval
    /// When true, every `GameSession.use...PowerUp()` method skips `PowerUpStore.consume`
    /// entirely — power-ups can be spammed for testing without touching real inventory.
    var debugInfinitePowerUps: Bool = false
    /// When true, `StoreManager.isPremiumUnlocked` reports unlocked regardless of real
    /// entitlement — lets premium-gated features be exercised without a sandbox purchase.
    /// Off by default, same as the other Dev Tools overrides.
    var debugForcePremiumUnlocked: Bool = false
    /// When true, `StoreManager.isPremiumUnlocked` reports locked regardless of a real
    /// entitlement (or the force-unlock override) — lets the non-VIP experience be tested
    /// on a device that already carries a lifetime purchase, without deleting the
    /// transaction in Xcode's StoreKit Transaction Manager. Off by default.
    var debugForcePremiumRemoved: Bool = false
    /// The name shown to friends on a sent Challenge Friends puzzle. Empty until the
    /// player is prompted the first time they try to send a challenge.
    var senderDisplayName: String = ""
    /// Master switch for Challenge Friends (menu entry, "Challenge a Friend" button, and
    /// receiving shared `.ntpchallenge` files). Off by default, same as Power-ups — the
    /// feature isn't manually verified on real hardware yet, so it ships hidden behind
    /// Settings' Dev Tools section rather than visible to everyone.
    var challengeFriendsEnabled: Bool = false
    /// Whether the Daily Challenge reminder notification is armed. On by default — actually
    /// scheduling it still waits for notification permission, requested the first time it can
    /// be tied to an engaged moment (first-ever daily completion, or first visit to the
    /// Notifications settings screen) rather than nagging on cold launch.
    var dailyReminderEnabled: Bool = true
    /// Only the hour/minute of this date are used — the day is irrelevant, it just needs
    /// to be a `Date` for `DatePicker` to bind to.
    var dailyReminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    /// Whether the "a new Daily Challenge is ready" notification is armed. Sent whether or
    /// not the player already completed today's challenge, unlike the reminder above. Off by
    /// default — stacked with Daily Reminder and Streak at Risk it's a third daily nudge
    /// toward the same action, so this one stays opt-in.
    var newChallengeAvailableEnabled: Bool = false
    /// Only the hour/minute of this date are used, same as `dailyReminderTime`.
    var newChallengeAvailableTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    /// Whether the late-day "your streak is about to lapse" nudge is armed. Fixed at 9 PM
    /// and only sent while an active streak would actually break — no user-configurable time.
    /// Off by default, same reasoning as `newChallengeAvailableEnabled`.
    var streakAtRiskEnabled: Bool = false
    /// Whether a celebration notification fires when the calendar streak hits a milestone
    /// (3, 7, 14, 30... days).
    var streakMilestonesEnabled: Bool = true
    /// Whether a Sunday-evening recap notification (days played, current streak) is armed.
    var weeklyRecapEnabled: Bool = true

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

    func setFeedbackIntensity(_ value: FeedbackIntensity) {
        feedbackIntensity = value
        defaults.set(value.rawValue, forKey: Keys.feedbackIntensity)
    }

    func setPowerUpsEnabled(_ value: Bool) {
        powerUpsEnabled = value
        defaults.set(value, forKey: Keys.powerUpsEnabled)
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

    func setDebugForcePremiumUnlocked(_ value: Bool) {
        debugForcePremiumUnlocked = value
        defaults.set(value, forKey: Keys.debugForcePremiumUnlocked)
    }

    func setDebugForcePremiumRemoved(_ value: Bool) {
        debugForcePremiumRemoved = value
        defaults.set(value, forKey: Keys.debugForcePremiumRemoved)
    }

    func setSenderDisplayName(_ name: String) {
        senderDisplayName = name
        defaults.set(name, forKey: Keys.senderDisplayName)
    }

    func setChallengeFriendsEnabled(_ value: Bool) {
        challengeFriendsEnabled = value
        defaults.set(value, forKey: Keys.challengeFriendsEnabled)
    }

    func setDailyReminderEnabled(_ value: Bool) {
        dailyReminderEnabled = value
        defaults.set(value, forKey: Keys.dailyReminderEnabled)
    }

    func setDailyReminderTime(_ time: Date) {
        dailyReminderTime = time
        defaults.set(time, forKey: Keys.dailyReminderTime)
    }

    func setNewChallengeAvailableEnabled(_ value: Bool) {
        newChallengeAvailableEnabled = value
        defaults.set(value, forKey: Keys.newChallengeAvailableEnabled)
    }

    func setNewChallengeAvailableTime(_ time: Date) {
        newChallengeAvailableTime = time
        defaults.set(time, forKey: Keys.newChallengeAvailableTime)
    }

    func setStreakAtRiskEnabled(_ value: Bool) {
        streakAtRiskEnabled = value
        defaults.set(value, forKey: Keys.streakAtRiskEnabled)
    }

    func setStreakMilestonesEnabled(_ value: Bool) {
        streakMilestonesEnabled = value
        defaults.set(value, forKey: Keys.streakMilestonesEnabled)
    }

    func setWeeklyRecapEnabled(_ value: Bool) {
        weeklyRecapEnabled = value
        defaults.set(value, forKey: Keys.weeklyRecapEnabled)
    }

    func resetSettings() {
        setPreviewDuration(3)
        setStreakCountdownDuration(30)
        setQuickSnapDuration(3)
        setQuickSnapUsesFrontCamera(false)
        setFeedbackIntensity(.standard)
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
        static let feedbackIntensity = "puzzle.feedbackIntensity"
        /// Superseded by `feedbackIntensity`, kept only so `restoreFromUserDefaults` can
        /// migrate players who had haptics turned off under the old on/off toggle.
        static let legacyHapticsEnabled = "puzzle.hapticsEnabled"
        static let powerUpsEnabled = "puzzle.powerUpsEnabled"
        static let debugOverlayEnabled = "puzzle.debugOverlayEnabled"
        static let peekDuration = "puzzle.peekDuration"
        static let streakMilestoneInterval = "puzzle.streakMilestoneInterval"
        static let debugInfinitePowerUps = "puzzle.debugInfinitePowerUps"
        static let debugForcePremiumUnlocked = "puzzle.debugForcePremiumUnlocked"
        static let debugForcePremiumRemoved = "puzzle.debugForcePremiumRemoved"
        static let senderDisplayName = "puzzle.senderDisplayName"
        static let challengeFriendsEnabled = "puzzle.challengeFriendsEnabled"
        static let dailyReminderEnabled = "puzzle.dailyReminderEnabled"
        static let dailyReminderTime = "puzzle.dailyReminderTime"
        static let newChallengeAvailableEnabled = "puzzle.newChallengeAvailableEnabled"
        static let newChallengeAvailableTime = "puzzle.newChallengeAvailableTime"
        static let streakAtRiskEnabled = "puzzle.streakAtRiskEnabled"
        static let streakMilestonesEnabled = "puzzle.streakMilestonesEnabled"
        static let weeklyRecapEnabled = "puzzle.weeklyRecapEnabled"
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
        if let rawValue = defaults.string(forKey: Keys.feedbackIntensity), let value = FeedbackIntensity(rawValue: rawValue) {
            feedbackIntensity = value
        } else if defaults.object(forKey: Keys.legacyHapticsEnabled) != nil {
            feedbackIntensity = defaults.bool(forKey: Keys.legacyHapticsEnabled) ? .standard : .off
        }
        if defaults.object(forKey: Keys.powerUpsEnabled) != nil {
            powerUpsEnabled = defaults.bool(forKey: Keys.powerUpsEnabled)
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
        if defaults.object(forKey: Keys.debugForcePremiumUnlocked) != nil {
            debugForcePremiumUnlocked = defaults.bool(forKey: Keys.debugForcePremiumUnlocked)
        }
        if defaults.object(forKey: Keys.debugForcePremiumRemoved) != nil {
            debugForcePremiumRemoved = defaults.bool(forKey: Keys.debugForcePremiumRemoved)
        }
        if let name = defaults.string(forKey: Keys.senderDisplayName) {
            senderDisplayName = name
        }
        if defaults.object(forKey: Keys.challengeFriendsEnabled) != nil {
            challengeFriendsEnabled = defaults.bool(forKey: Keys.challengeFriendsEnabled)
        }
        if defaults.object(forKey: Keys.dailyReminderEnabled) != nil {
            dailyReminderEnabled = defaults.bool(forKey: Keys.dailyReminderEnabled)
        }
        if let time = defaults.object(forKey: Keys.dailyReminderTime) as? Date {
            dailyReminderTime = time
        }
        if defaults.object(forKey: Keys.newChallengeAvailableEnabled) != nil {
            newChallengeAvailableEnabled = defaults.bool(forKey: Keys.newChallengeAvailableEnabled)
        }
        if let time = defaults.object(forKey: Keys.newChallengeAvailableTime) as? Date {
            newChallengeAvailableTime = time
        }
        if defaults.object(forKey: Keys.streakAtRiskEnabled) != nil {
            streakAtRiskEnabled = defaults.bool(forKey: Keys.streakAtRiskEnabled)
        }
        if defaults.object(forKey: Keys.streakMilestonesEnabled) != nil {
            streakMilestonesEnabled = defaults.bool(forKey: Keys.streakMilestonesEnabled)
        }
        if defaults.object(forKey: Keys.weeklyRecapEnabled) != nil {
            weeklyRecapEnabled = defaults.bool(forKey: Keys.weeklyRecapEnabled)
        }
    }
}
