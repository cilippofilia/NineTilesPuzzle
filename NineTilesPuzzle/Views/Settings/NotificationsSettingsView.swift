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
                    set: { handleToggle($0, setEnabled: settings.setDailyReminderEnabled, onChange: refreshDailyReminder) }
                ))

                if settings.dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { settings.dailyReminderTime },
                            set: { newTime in
                                settings.setDailyReminderTime(newTime)
                                refreshDailyReminder()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } footer: {
                Text("A single reminder to play today's Daily Challenge — only sent if you haven't completed it yet.")
            }

            Section {
                Toggle("New Puzzle Available", isOn: Binding(
                    get: { settings.newChallengeAvailableEnabled },
                    set: { handleToggle($0, setEnabled: settings.setNewChallengeAvailableEnabled, onChange: refreshNewChallengeAvailable) }
                ))

                if settings.newChallengeAvailableEnabled {
                    DatePicker(
                        "Notify At",
                        selection: Binding(
                            get: { settings.newChallengeAvailableTime },
                            set: { newTime in
                                settings.setNewChallengeAvailableTime(newTime)
                                refreshNewChallengeAvailable()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } footer: {
                Text("A daily heads-up when a new puzzle is ready — sent whether or not you've already played.")
            }

            Section {
                Toggle("Streak at Risk", isOn: Binding(
                    get: { settings.streakAtRiskEnabled },
                    set: { handleToggle($0, setEnabled: settings.setStreakAtRiskEnabled, onChange: refreshStreakAtRisk) }
                ))
            } footer: {
                Text("A 9 PM nudge if your streak is about to end — only sent when you have an active streak and haven't played yet.")
            }

            Section {
                Toggle("Streak Milestones", isOn: Binding(
                    get: { settings.streakMilestonesEnabled },
                    set: { handleToggle($0, setEnabled: settings.setStreakMilestonesEnabled, onChange: {}) }
                ))
            } footer: {
                Text("A celebration when your streak hits a milestone, like 7, 30, or 100 days.")
            }

            Section {
                Toggle("Weekly Recap", isOn: Binding(
                    get: { settings.weeklyRecapEnabled },
                    set: { handleToggle($0, setEnabled: settings.setWeeklyRecapEnabled, onChange: refreshWeeklyRecap) }
                ))
            } footer: {
                Text("A Sunday evening summary of how many days you played and your current streak.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await requestPermissionIfNeededOnFirstVisit() }
        .alert("Notifications Are Off", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Nine Tiles Puzzle in Settings to turn this reminder on.")
        }
    }

    /// Every toggle on this screen shares one system permission, so turning any of them on
    /// needs the same round trip through the permission prompt (or, if already denied, a
    /// nudge to the Settings app) before the store's flag is set and the notification armed.
    private func handleToggle(_ isOn: Bool, setEnabled: @escaping (Bool) -> Void, onChange: @escaping () -> Void) {
        guard isOn else {
            setEnabled(false)
            onChange()
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
            setEnabled(true)
            onChange()
        }
    }

    private func refreshDailyReminder() {
        dailyReminderService.rescheduleIfNeeded(
            enabled: settings.dailyReminderEnabled,
            time: settings.dailyReminderTime,
            completedToday: dailyStore.isDailyCompletedToday
        )
    }

    private func refreshNewChallengeAvailable() {
        dailyReminderService.rescheduleNewChallengeAvailableIfNeeded(
            enabled: settings.newChallengeAvailableEnabled,
            time: settings.newChallengeAvailableTime
        )
    }

    private func refreshStreakAtRisk() {
        dailyReminderService.rescheduleStreakAtRiskIfNeeded(
            enabled: settings.streakAtRiskEnabled,
            calendarStreak: dailyStore.calendarStreak,
            completedToday: dailyStore.isDailyCompletedToday
        )
    }

    private func refreshWeeklyRecap() {
        dailyReminderService.rescheduleWeeklyRecapIfNeeded(
            enabled: settings.weeklyRecapEnabled,
            completedDaysThisWeek: dailyStore.completedDaysInTrailingWeek(),
            calendarStreak: dailyStore.calendarStreak
        )
    }

    /// Every toggle here defaults to on, but nothing is actually scheduled until permission
    /// is granted. `PuzzleView` requests it after the first-ever Daily Challenge completion —
    /// this is the fallback for a player who opens this screen before that ever happens, so
    /// the toggles don't sit "on" indefinitely without anything behind them. Only resolves
    /// permission once (`authorizationStatus == .notDetermined`); afterward every toggle is
    /// driven by `handleToggle` or the app-level foreground refresh instead.
    private func requestPermissionIfNeededOnFirstVisit() async {
        await dailyReminderService.refreshAuthorizationStatus()
        guard dailyReminderService.authorizationStatus == .notDetermined else { return }

        let anyEnabled = settings.dailyReminderEnabled
            || settings.newChallengeAvailableEnabled
            || settings.streakAtRiskEnabled
            || settings.streakMilestonesEnabled
            || settings.weeklyRecapEnabled
        guard anyEnabled else { return }

        let granted = await dailyReminderService.requestAuthorization()
        guard granted else {
            if settings.dailyReminderEnabled { settings.setDailyReminderEnabled(false) }
            if settings.newChallengeAvailableEnabled { settings.setNewChallengeAvailableEnabled(false) }
            if settings.streakAtRiskEnabled { settings.setStreakAtRiskEnabled(false) }
            if settings.streakMilestonesEnabled { settings.setStreakMilestonesEnabled(false) }
            if settings.weeklyRecapEnabled { settings.setWeeklyRecapEnabled(false) }
            return
        }
        refreshDailyReminder()
        refreshNewChallengeAvailable()
        refreshStreakAtRisk()
        refreshWeeklyRecap()
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
