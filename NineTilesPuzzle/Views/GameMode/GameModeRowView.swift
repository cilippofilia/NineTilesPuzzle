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

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}
