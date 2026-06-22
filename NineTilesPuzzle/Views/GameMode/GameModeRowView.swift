//
//  GameModeRowView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/21/26.
//

import SwiftUI

struct GameModeRowView: View {
    let mode: GameMode
    let isSelected: Bool

    var body: some View {
        HStack {
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

            Spacer()

            // Rendered unconditionally (just hidden via opacity) rather than `if isSelected`,
            // so the checkmark always reserves the same horizontal space — otherwise the
            // label's available text width changes between selected/unselected, which can
            // shift a description's line count and jump the whole list's layout.
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
        }
    }
}
