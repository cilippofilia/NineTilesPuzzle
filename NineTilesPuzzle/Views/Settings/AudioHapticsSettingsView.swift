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
            Section("Audio") {
                Toggle(isOn: Binding(
                    get: { soundService.isTileMoveEnabled },
                    set: { soundService.setTileMoveEnabled($0) }
                )) {
                    SoundToggleLabel(title: "Tile Move Sound", soundName: soundService.tileMoveSoundName)
                }

                Toggle(isOn: Binding(
                    get: { soundService.isCompletionEnabled },
                    set: { soundService.setCompletionEnabled($0) }
                )) {
                    SoundToggleLabel(title: "Completion Sound", soundName: soundService.completionSoundName)
                }
            }

            Section("Haptics") {
                Toggle("Haptic Feedback", isOn: Binding(
                    get: { settings.hapticsEnabled },
                    set: { settings.setHapticsEnabled($0) }
                ))
                .sensoryFeedback(.impact, trigger: settings.hapticsEnabled) { _, newValue in
                    newValue
                }
            }
        }
        .navigationTitle("Audio & Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SoundToggleLabel: View {
    let title: String
    let soundName: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(soundName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AudioHapticsSettingsView()
            .environment(SettingsStore())
            .environment(SoundService())
    }
}
