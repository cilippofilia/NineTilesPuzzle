//
//  BrandPuzzleMark.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// The app's brand glyph — a tilted puzzle piece with the red→yellow gradient — used as the
/// Dynamic Island's compact and minimal presentation so the activity reads as "Nine Tiles" at a
/// glance rather than as a mode-specific symbol.
struct BrandPuzzleMark: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "puzzlepiece.fill")
            .resizable()
            .scaledToFit()
            .rotationEffect(.degrees(-45))
            .foregroundStyle(
                LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
            )
            .frame(width: size, height: size)
    }
}
