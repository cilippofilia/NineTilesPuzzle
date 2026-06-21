//
//  MediaSourceRowView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/21/26.
//

import SwiftUI

struct MediaSourceRowView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                MediaSourceLabelView(title: title, subtitle: subtitle, isSelected: isSelected)
            }
            .foregroundStyle(.primary)
        } else {
            MediaSourceLabelView(title: title, subtitle: subtitle, isSelected: isSelected)
                .foregroundStyle(.secondary)
        }
    }
}
