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
    @Environment(SoundService.self) private var soundService
    @Environment(\.dismiss) private var dismiss

    @State private var showResetStatsAlert = false
    @State private var showResetSettingsAlert = false
    @State private var showDebugOverlayAlert = false

    var body: some View {
        NavigationStack {
            List {
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
                        }
                    } header: {
                        Text("Daily Challenge")
                    } footer: {
                        Text("Offset shifts the puzzle date so you can test different modes and grid sizes. Reset clears today's completion so the Play button reappears.")
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
                Button("Reset", role: .destructive) { statsStore.resetStats() }
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
                Text("Media source, preview time, streak countdown, and difficulty will be restored to their default values.")
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
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SettingsView()
                .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily))
                .environment(stats)
                .environment(settings)
                .environment(daily)
                .environment(SoundService())
        }
}
