//
//  NotificationsSettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DailyChallengeStore.self) private var dailyStore
    @Environment(DailyReminderService.self) private var dailyReminderService

    @State private var showNotificationDeniedAlert = false

    var body: some View {
        List {
            Section {
                Toggle("Daily Reminder", isOn: Binding(
                    get: { settings.dailyReminderEnabled },
                    set: handleReminderToggle
                ))

                if settings.dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { settings.dailyReminderTime },
                            set: { newTime in
                                settings.setDailyReminderTime(newTime)
                                dailyReminderService.rescheduleIfNeeded(
                                    enabled: true,
                                    time: newTime,
                                    completedToday: dailyStore.isDailyCompletedToday
                                )
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } footer: {
                Text("A single reminder to play today's Daily Challenge — only sent if you haven't completed it yet.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications Are Off", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Nine Tiles Puzzle in Settings to turn on the Daily Reminder.")
        }
    }

    /// Turning the toggle on needs a round trip through the system permission prompt (or,
    /// if already denied, a nudge to the Settings app) before the reminder can actually be
    /// armed — so the store's `dailyReminderEnabled` is only set once that's resolved.
    private func handleReminderToggle(_ isOn: Bool) {
        guard isOn else {
            settings.setDailyReminderEnabled(false)
            dailyReminderService.cancelReminder()
            return
        }
        if dailyReminderService.authorizationStatus == .denied {
            showNotificationDeniedAlert = true
            return
        }
        Task {
            let granted = dailyReminderService.authorizationStatus == .authorized
                ? true
                : await dailyReminderService.requestAuthorization()
            guard granted else {
                showNotificationDeniedAlert = true
                return
            }
            settings.setDailyReminderEnabled(true)
            dailyReminderService.rescheduleIfNeeded(
                enabled: true,
                time: settings.dailyReminderTime,
                completedToday: dailyStore.isDailyCompletedToday
            )
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
            .environment(SettingsStore())
            .environment(DailyChallengeStore())
            .environment(DailyReminderService())
    }
}
