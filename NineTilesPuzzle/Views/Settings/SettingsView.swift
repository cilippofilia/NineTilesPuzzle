//
//  SettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(PuzzleState.self) private var state
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
                        PhotoSourcePickerView()
                    } label: {
                        LabeledContent("Photo Source", value: state.imageSourceType.label)
                    }

                    NavigationLink {
                        PreviewTimePickerView()
                    } label: {
                        LabeledContent("Preview Time", value: state.previewDurationLabel)
                    }

                    NavigationLink {
                        StreakCountdownPickerView()
                    } label: {
                        LabeledContent("Streak Countdown", value: state.streakCountdownLabel)
                    }
                }

                Section("Audio") {
                    Toggle("Sound Effects", isOn: Binding(
                        get: { soundService.isEnabled },
                        set: { soundService.setEnabled($0) }
                    ))

                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { state.hapticsEnabled },
                        set: { state.setHapticsEnabled($0) }
                    ))
                }

                Section("Super easy mode?") {
                    Toggle("Show Tile Indices", isOn: Binding(
                        get: { state.debugOverlayEnabled },
                        set: { newValue in
                            if newValue {
                                showDebugOverlayAlert = true
                            } else {
                                state.setDebugOverlayEnabled(false)
                            }
                        }
                    ))
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
                Button("Reset", role: .destructive) { state.resetStats() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current streak, best streak, move counter, and personal bests will be cleared.")
            }
            .alert("Reset Settings?", isPresented: $showResetSettingsAlert) {
                Button("Reset", role: .destructive) { state.resetSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photo source, preview time, streak countdown, and difficulty will be restored to their default values.")
            }
            .alert("Turn On Tile Indices?", isPresented: $showDebugOverlayAlert) {
                Button("Turn On") { state.setDebugOverlayEnabled(true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("While enabled, your streak, best moves, games played, and achievements won't be updated. Turn this off to resume tracking your progress.")
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SettingsView()
                .environment(PuzzleState())
                .environment(SoundService())
        }
}
