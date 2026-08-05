//
//  DailyReminderService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import UserNotifications

/// Wraps `UNUserNotificationCenter` to manage every local notification this app sends:
/// a reminder to come play the Daily Challenge, a heads-up that a new one dropped, a
/// late-day nudge when an active streak is about to lapse, a celebration when a streak
/// hits a milestone, and a weekly recap. Each kind owns a fixed identifier, so scheduling
/// one always starts by replacing whatever was pending under that identifier — at most one
/// of each kind is ever pending at a time.
@MainActor
@Observable
final class DailyReminderService {
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private let center = UNUserNotificationCenter.current()
    private let defaults: PersistenceStore
    /// `UNUserNotificationCenter.delegate` is weak, so this needs to be held onto — without
    /// it, a milestone notification fired while the app is foregrounded (right after solving)
    /// would be delivered silently instead of showing a banner.
    private let foregroundPresenter = ForegroundNotificationPresenter()

    private static let identifier = "dailyReminder"
    private static let newChallengeIdentifier = "newChallengeAvailable"
    private static let streakAtRiskIdentifier = "streakAtRisk"
    private static let streakMilestoneIdentifier = "streakMilestone"
    private static let weeklyRecapIdentifier = "weeklyRecap"

    /// Calendar-streak lengths celebrated with a milestone notification.
    private static let streakMilestones: [Int] = [3, 7, 14, 30, 50, 100, 200, 365]

    /// Candidate reminder bodies. `nextReminderBody()` draws from this without repeating
    /// one until every other message has been shown, so the notification doesn't feel
    /// like it's reading from a script.
    private static let messages: [String] = [
        "Today's puzzle is waiting — keep your streak alive!",
        "Your streak is counting on you. Play today's Daily Challenge!",
        "Nine tiles, one puzzle, zero excuses — today's challenge is ready.",
        "Don't break the chain — solve today's puzzle.",
        "A fresh puzzle dropped today. Come give it a shot!",
        "Keep the streak going — today's challenge is live.",
        "Your daily puzzle is calling.",
        "Still time to keep your streak alive — today's puzzle awaits.",
    ]

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        center.delegate = foregroundPresenter
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = Self.status(for: settings.authorizationStatus)
    }

    /// Shows the system permission prompt. Safe to call even if already decided —
    /// the system only prompts once and just reports the existing answer afterward.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    /// Arms the reminder for the next occurrence of `time`'s hour/minute — today if that
    /// time hasn't passed yet and the challenge isn't done, tomorrow otherwise. A one-shot
    /// trigger is used instead of a repeating one so completing today's challenge (or the
    /// time already having passed) can skip straight to tomorrow rather than firing anyway.
    ///
    /// Call this after every daily completion and whenever the app returns to the
    /// foreground, since a trigger that already fired (or was skipped) needs replacing.
    func rescheduleIfNeeded(enabled: Bool, time: Date, completedToday: Bool) {
        cancelReminder()
        guard enabled, authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let timeOfDay = calendar.dateComponents([.hour, .minute], from: time)
        var fireDate = calendar.date(
            bySettingHour: timeOfDay.hour ?? 20, minute: timeOfDay.minute ?? 0, second: 0, of: .now
        ) ?? .now
        if completedToday || fireDate <= .now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge"
        content.body = nextReminderBody()
        content.sound = .default

        let fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelNewChallengeAvailable() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.newChallengeIdentifier])
    }

    /// Arms a daily heads-up that a new Daily Challenge is ready, at `time`'s hour/minute —
    /// sent whether or not the player has already completed it, unlike the reminder above.
    /// The message never depends on same-day data, so a single repeating trigger covers
    /// every future day without needing to be re-armed daily.
    func rescheduleNewChallengeAvailableIfNeeded(enabled: Bool, time: Date) {
        cancelNewChallengeAvailable()
        guard enabled, authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Puzzle"
        content.body = "Today's Daily Challenge just dropped — come give it a shot!"
        content.sound = .default

        let timeOfDay = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeOfDay, repeats: true)
        let request = UNNotificationRequest(identifier: Self.newChallengeIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelStreakAtRisk() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.streakAtRiskIdentifier])
    }

    /// Arms a late-day, last-chance nudge — only while an active streak (2+ days) would
    /// actually lapse: today isn't completed yet. Fixed at 9 PM rather than user-configurable,
    /// since the whole point is to land after the player would normally have played but
    /// before the day runs out. A one-shot trigger, re-armed on every foreground/completion
    /// like the reminder above, since "is there a streak at risk" changes day to day.
    func rescheduleStreakAtRiskIfNeeded(enabled: Bool, calendarStreak: Int, completedToday: Bool) {
        cancelStreakAtRisk()
        guard enabled, authorizationStatus == .authorized, calendarStreak >= 2, !completedToday else { return }

        let calendar = Calendar.current
        let fireDate = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Streak at Risk"
        content.body = "Your \(calendarStreak)-day streak ends at midnight — solve today's puzzle to keep it going."
        content.sound = .default

        let fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
        let request = UNNotificationRequest(identifier: Self.streakAtRiskIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelWeeklyRecap() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapIdentifier])
    }

    /// Arms a Sunday-evening recap, fixed at 6 PM. Since a repeating trigger's content is
    /// fixed at schedule time, the numbers baked in here go stale until the next reschedule —
    /// call this from the same foreground refresh hook that keeps the other reminders in sync,
    /// so the recap reflects a launch-time snapshot rather than the exact moment it fires.
    func rescheduleWeeklyRecapIfNeeded(enabled: Bool, completedDaysThisWeek: Int, calendarStreak: Int) {
        cancelWeeklyRecap()
        guard enabled, authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = weeklyRecapBody(completedDays: completedDaysThisWeek, calendarStreak: calendarStreak)
        content.sound = .default

        var fireComponents = DateComponents()
        fireComponents.weekday = 1
        fireComponents.hour = 18
        fireComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklyRecapIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Fires immediately when the calendar streak just crossed one of `streakMilestones`,
    /// at most once per milestone value — replaying an already-completed day (which doesn't
    /// advance the streak) can call this repeatedly without spamming the same celebration.
    func sendStreakMilestoneNotificationIfNeeded(calendarStreak: Int) {
        guard authorizationStatus == .authorized, Self.streakMilestones.contains(calendarStreak) else { return }
        guard defaults.integer(forKey: Keys.lastMilestoneStreak) != calendarStreak else { return }
        defaults.set(calendarStreak, forKey: Keys.lastMilestoneStreak)

        let content = UNMutableNotificationContent()
        content.title = "🔥 \(calendarStreak)-Day Streak!"
        content.body = "You've played the Daily Challenge \(calendarStreak) days in a row. Keep it up!"
        content.sound = .default

        let request = UNNotificationRequest(identifier: Self.streakMilestoneIdentifier, content: content, trigger: nil)
        center.add(request)
    }

    private func weeklyRecapBody(completedDays: Int, calendarStreak: Int) -> String {
        let dayWord = completedDays == 1 ? "day" : "days"
        let base = "You played the Daily Challenge \(completedDays) \(dayWord) in the last week."
        guard calendarStreak >= 2 else { return base }
        return base + " Current streak: \(calendarStreak) 🔥"
    }

    /// Draws a message from the shrinking pool of not-yet-shown messages, refilling from
    /// `messages` once it's empty. The message that just ran out the previous pool is
    /// excluded from the refill draw so the same body can't land on two reminders in a row.
    private func nextReminderBody() -> String {
        var pool = defaults.object(forKey: Keys.messagePool) as? [String] ?? []
        if pool.isEmpty {
            pool = Self.messages
        }

        var candidates = pool
        if pool.count > 1, let lastMessage = defaults.string(forKey: Keys.lastMessage) {
            candidates.removeAll { $0 == lastMessage }
        }

        let message = candidates.randomElement() ?? pool.randomElement() ?? Self.messages[0]
        pool.removeAll { $0 == message }
        defaults.set(pool, forKey: Keys.messagePool)
        defaults.set(message, forKey: Keys.lastMessage)
        return message
    }

    private enum Keys {
        static let messagePool = "dailyReminder.messagePool"
        static let lastMessage = "dailyReminder.lastMessage"
        static let lastMilestoneStreak = "dailyReminder.lastMilestoneStreak"
    }

    private static func status(for status: UNAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .notDetermined
        }
    }
}

/// Lets a notification fired while the app is foregrounded (the streak-milestone
/// celebration, sent right after solving) still show a banner instead of being delivered
/// silently, which is `UNUserNotificationCenter`'s default behavior in the foreground.
@MainActor
private final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
