//
//  GameModeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import SwiftUI

struct GameModeView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(GameMode.allCases) { mode in
            if mode.isAvailable {
                Button {
                    state.setGameMode(mode)
                    dismiss()
                } label: {
                    GameModeRowView(mode: mode, isSelected: state.selectedGameMode == mode)
                }
                .foregroundStyle(.primary)
            } else {
                GameModeRowView(mode: mode, isSelected: false)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Game Modes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GameModeRowView: View {
    let mode: GameMode
    let isSelected: Bool

    var body: some View {
        LabeledContent {
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        } label: {
            Label {
                VStack(alignment: .leading) {
                    HStack {
                        Text(mode.title)
                        if !mode.isAvailable {
                            Text("(Coming soon…)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: mode.icon)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameModeView()
            .environment(PuzzleState())
    }
}
