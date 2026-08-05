//
//  GameplaySettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import SwiftUI

struct GameplaySettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(StatsStore.self) private var statsStore
    @Environment(GameSession.self) private var session

    @State private var showResetStatsAlert = false

    var body: some View {
        List {
            Section {
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
                Button("Reset Stats", role: .destructive) {
                    showResetStatsAlert = true
                }
            }
        }
        .navigationTitle("Gameplay")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Stats?", isPresented: $showResetStatsAlert) {
            Button("Reset", role: .destructive) {
                statsStore.resetStats()
                session.syncWidgetsAfterReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current streak, best streak, move counter, personal bests, and games played will be cleared.")
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()

    return NavigationStack {
        GameplaySettingsView()
            .environment(settings)
            .environment(stats)
            .environment(GameSession(statsStore: stats, achievementsStore: AchievementsStore(), settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: PowerUpStore(), challengeStore: ChallengeStore()))
    }
}
