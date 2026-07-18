//
//  MediaSourceLabelView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/21/26.
//

import SwiftUI

struct MediaSourceLabelView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var isLocked: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .saturation(isLocked ? 0 : 1)

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
