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
    @Environment(\.dismiss) private var dismiss

    @State private var showResetStatsAlert = false
    @State private var showResetSettingsAlert = false
    @State private var showDebugOverlayAlert = false

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
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
                        Text("Infinite Power-ups lets every power-up be used without spending inventory. The steppers tune how long a Peek/Hint shows and how often a streak milestone earns a power-up. Refill tops every power-up back up to 3 for testing.")
                    }
                }
                #endif

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

                Section("Audio") {
                    Toggle("Sound Effects", isOn: Binding(
                        get: { soundService.isEnabled },
                        set: { soundService.setEnabled($0) }
                    ))

                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { settings.setHapticsEnabled($0) }
                    ))
                }

                Section("Widgets") {
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
        }
        .presentationDetents([.medium, .large])
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
                .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily, powerUpStore: powerUps))
                .environment(stats)
                .environment(settings)
                .environment(daily)
                .environment(SoundService())
                .environment(GameCenterService())
        }
}
