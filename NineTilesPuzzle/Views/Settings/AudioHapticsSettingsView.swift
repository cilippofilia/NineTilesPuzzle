//
//  AudioHapticsSettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import SwiftUI

struct AudioHapticsSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(SoundService.self) private var soundService

    var body: some View {
        List {
            Section {
                Picker("Feedback Intensity", selection: Binding(
                    get: { settings.feedbackIntensity },
                    set: { settings.setFeedbackIntensity($0) }
                )) {
                    ForEach(FeedbackIntensity.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(trigger: settings.feedbackIntensity) { _, newValue in
                    newValue.impactFeedback()
                }
            } header: {
                Text("Haptic Feedback")
            } footer: {
                Text("Sets how strong haptics feel and how loud sound effects play, from Off to Strong.")
            }

            Section("Audio") {
                SoundControlRow(
                    title: "Tile Move Sound",
                    soundName: soundService.tileMoveSoundName,
                    isEnabled: Binding(
                        get: { soundService.isTileMoveEnabled },
                        set: { soundService.setTileMoveEnabled($0) }
                    ),
                    volume: Binding(
                        get: { soundService.tileMoveVolume },
                        set: { soundService.setTileMoveVolume($0) }
                    )
                )

                SoundControlRow(
                    title: "Completion Sound",
                    soundName: soundService.completionSoundName,
                    isEnabled: Binding(
                        get: { soundService.isCompletionEnabled },
                        set: { soundService.setCompletionEnabled($0) }
                    ),
                    volume: Binding(
                        get: { soundService.completionVolume },
                        set: { soundService.setCompletionVolume($0) }
                    )
                )
            }
        }
        .navigationTitle("Audio & Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SoundControlRow: View {
    let title: String
    let soundName: String
    @Binding var isEnabled: Bool
    @Binding var volume: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(soundName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Slider(value: $volume, in: 0...1) {
                    Text(title)
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .disabled(!isEnabled)

                Text(volume, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.default, value: volume)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AudioHapticsSettingsView()
            .environment(SettingsStore())
            .environment(SoundService())
    }
}
