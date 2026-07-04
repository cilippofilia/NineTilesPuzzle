//
//  BoardThumbnail.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// Loads a board snapshot from the shared container, falling back to a puzzle-piece glyph if the
/// file is missing (e.g. cleaned up between updates), inside a rounded, subtly bordered frame.
struct BoardThumbnail: View {
    let imageName: String
    let cornerRadius: CGFloat

    var body: some View {
        content
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if let url = LiveActivityStore.boardImageURL(named: imageName),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.black.opacity(0.4)
                Image(systemName: "puzzlepiece.fill")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
