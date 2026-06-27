//
//  StreakCountdownPickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct StreakCountdownPickerView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(GameSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("Off", 0),
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120)
    ]

    var body: some View {
        List {
            ForEach(options, id: \.value) { option in
                Button {
                    settings.setStreakCountdownDuration(option.value)
                    if option.value == 0 { session.stopCountdown() }
                    dismiss()
                } label: {
                    LabeledContent {
                        if settings.streakCountdownDuration == option.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    } label: {
                        Text(option.label)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Streak Countdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    NavigationStack {
        StreakCountdownPickerView()
            .environment(settings)
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore()))
    }
}
