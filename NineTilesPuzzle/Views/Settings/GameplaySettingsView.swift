//
//  GameplaySettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import SwiftUI

struct GameplaySettingsView: View {
    @Environment(SettingsStore.self) private var settings

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
        }
        .navigationTitle("Gameplay")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GameplaySettingsView()
            .environment(SettingsStore())
    }
}
