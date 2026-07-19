//
//  DailyReminderService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import UserNotifications

/// Wraps `UNUserNotificationCenter` to manage the single local notification this app
/// sends: a reminder to come play the Daily Challenge. Only one is ever pending at a
/// time, keyed by `identifier`, so scheduling always starts by replacing whatever was
/// there before.
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
    private static let identifier = "dailyReminder"

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
