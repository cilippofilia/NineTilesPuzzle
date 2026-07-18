//
//  SettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(GameSession.self) private var session
    @Environment(StatsStore.self) private var statsStore
    @Environment(SettingsStore.self) private var settings
    @Environment(DailyChallengeStore.self) private var dailyStore
    @Environment(PowerUpStore.self) private var powerUpStore
    @Environment(SoundService.self) private var soundService
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DailyReminderService.self) private var dailyReminderService
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showResetStatsAlert = false
    @State private var showResetSettingsAlert = false
    @State private var showDebugOverlayAlert = false
    @State private var showNotificationDeniedAlert = false
    @State private var paywallContext: PaywallContext?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.isPremiumUnlocked {
                        Label {
                            Text("VIP Unlocked")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.white)
                        }
                    } else {
                        Button {
                            paywallContext = .general
                        } label: {
                            Label {
                                Text("Unlock Nine Tiles Puzzle VIP")
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                } footer: {
                    if !store.isPremiumUnlocked {
                        Text("Unlock every game mode, personalize puzzles with your own photos, and get the full experience.")
                    }
                }

                Section {
                    Toggle("Show debug tools", isOn: Binding(
                        get: { settings.debugOverlayEnabled },
                        set: { newValue in
                            if newValue {
                                showDebugOverlayAlert = true
                            } else {
                                settings.setDebugOverlayEnabled(false)
                            }
                        }
                    ))
                } header: {
                    Text("Dev Tools")
                } footer: {
                    Text("This feature is for development testing only and is not intended for production use.")
                }

                if settings.debugOverlayEnabled {
                    Section {
                        Stepper(
                            "Day offset: \(dailyStore.debugDayOffset > 0 ? "+" : "")\(dailyStore.debugDayOffset)",
                            value: Binding(
                                get: { dailyStore.debugDayOffset },
                                set: { dailyStore.setDebugDayOffset($0) }
                            )
                        )

                        Button("Reset Today's Completion") {
                            dailyStore.resetCompletionForDebug()
                            session.syncWidgetsAfterReset()
                        }
                    } header: {
                        Text("Daily Challenge")
                    } footer: {
                        Text("Offset shifts the puzzle date so you can test different modes and grid sizes. Reset clears today's completion so the Play button reappears.")
                    }

                    Section {
                        Toggle("Enable Power-ups", isOn: Binding(
                            get: { settings.powerUpsEnabled },
                            set: { settings.setPowerUpsEnabled($0) }
                        ))

                        Toggle("Infinite Power-ups", isOn: Binding(
                            get: { settings.debugInfinitePowerUps },
                            set: { settings.setDebugInfinitePowerUps($0) }
                        ))

                        Stepper(
                            "Peek duration: \(Int(settings.peekDuration))s",
                            value: Binding(
                                get: { settings.peekDuration },
                                set: { settings.setPeekDuration($0) }
                            ),
                            in: 1...15
                        )

                        Stepper(
                            "Streak milestone: every \(settings.streakMilestoneInterval)",
                            value: Binding(
                                get: { settings.streakMilestoneInterval },
                                set: { settings.setStreakMilestoneInterval($0) }
                            ),
                            in: 1...20
                        )

                        Button("Refill Power-ups (3 each)") {
                            powerUpStore.resetToDefaults()
                        }
                    } header: {
                        Text("Power-ups")
                    } footer: {
                        Text("Enable Power-ups turns on the power-up system in-game — it's off by default while still being tuned. Infinite Power-ups lets every power-up be used without spending inventory. The steppers tune how long a Peek/Hint shows and how often a streak milestone earns a power-up. Refill tops every power-up back up to 3 for testing.")
                    }

                    Section {
                        Toggle("Enable Challenge Friends", isOn: Binding(
                            get: { settings.challengeFriendsEnabled },
                            set: { settings.setChallengeFriendsEnabled($0) }
                        ))

                        if settings.challengeFriendsEnabled {
                            TextField("Your Game tag", text: Binding(
                                get: { settings.senderDisplayName },
                                set: { settings.setSenderDisplayName($0) }
                            ))
                        }
                    } header: {
                        Text("Challenge Friends")
                    } footer: {
                        Text("Send a friend a seeded puzzle and compare move counts, by file share or nearby device — it's off by default while it's still unverified on real hardware. Your Game tag is shown to friends when you send them a challenge.")
                    }
                }

                Section("Game") {
                    NavigationLink {
                        PreviewTimePickerView()
                    } label: {
                        LabeledContent("Preview Time", value: settings.previewDurationLabel)
                    }

                    NavigationLink {
                        StreakCountdownPickerView()
                    } label: {
                        LabeledContent("Streak Countdown", value: settings.streakCountdownLabel)
                    }

                    // Only relevant on hardware that can actually shoot — hidden alongside the
                    // rest of Quick Snap on camera-less devices and the Simulator.
                    if QuickSnapCameraSession.isCameraAvailable {
                        NavigationLink {
                            QuickSnapDurationPickerView()
                        } label: {
                            LabeledContent("Quick Snap Timer", value: settings.quickSnapDurationLabel)
                        }
                    }

                    NavigationLink {
                        StatsView()
                    } label: {
                        Text("Stats")
                    }
                }

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
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("A single reminder to play today's Daily Challenge — only sent if you haven't completed it yet.")
                }

                Section("Audio") {
                    Toggle("Sound Effects", isOn: Binding(
                        get: { soundService.isEnabled },
                        set: { soundService.setEnabled($0) }
                    ))

                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { settings.setHapticsEnabled($0) }
                    ))
                    .sensoryFeedback(.impact, trigger: settings.hapticsEnabled) { _, newValue in
                        newValue
                    }
                }

                Section("How to...") {
                    NavigationLink {
                        WidgetsGuideView()
                    } label: {
                        Label {
                            Text("How to Add Widgets")
                        } icon: {
                            Image(systemName: "widget.small.badge.plus")
                                .foregroundStyle(.white)
                        }
                    }

                    if settings.powerUpsEnabled {
                        NavigationLink {
                            PowerUpsGuideView()
                        } label: {
                            Label {
                                Text("How to Use Power-ups")
                            } icon: {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                if gameCenterService.isAuthenticated {
                    Section("Game Center") {
                        Button("Open Game Center") {
                            gameCenterService.showDashboard()
                        }
                    }
                }

                Section {
                    Button("Reset Stats", role: .destructive) {
                        showResetStatsAlert = true
                    }

                    Button("Reset Settings", role: .destructive) {
                        showResetSettingsAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Stats?", isPresented: $showResetStatsAlert) {
                Button("Reset", role: .destructive) {
                    statsStore.resetStats()
                    session.syncWidgetsAfterReset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current streak, best streak, move counter, personal bests, and games played will be cleared.")
            }
            .alert("Reset Settings?", isPresented: $showResetSettingsAlert) {
                Button("Reset", role: .destructive) {
                    session.resetConfiguration()
                    settings.resetSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Media source, preview time, streak countdown, Quick Snap timer, and difficulty will be restored to their default values.")
            }
            .alert("Turn On Tile Indices?", isPresented: $showDebugOverlayAlert) {
                Button("Turn On") { settings.setDebugOverlayEnabled(true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("While enabled, your streak, best moves, games played, and achievements won't be updated. Turn this off to resume tracking your progress.")
            }
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
        .paywallSheet(context: $paywallContext)
        .presentationDetents([.medium, .large])
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
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let daily = DailyChallengeStore()
    let powerUps = PowerUpStore()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SettingsView()
                .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily, powerUpStore: powerUps, challengeStore: ChallengeStore()))
                .environment(stats)
                .environment(settings)
                .environment(daily)
                .environment(SoundService())
                .environment(GameCenterService())
                .environment(DailyReminderService())
                .environment(StoreManager())
        }
}
