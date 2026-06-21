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

    var body: some View {
        LabeledContent {
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        } label: {
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
