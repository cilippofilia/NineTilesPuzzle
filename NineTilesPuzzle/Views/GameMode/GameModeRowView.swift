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
    var isLocked: Bool = false

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
                .saturation(isLocked ? 0 : 1)
            } icon: {
                Image(systemName: mode.icon)
                    .saturation(isLocked ? 0 : 1)
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
                    .animation(nil, value: isSelected)
            }
        }
    }
}
