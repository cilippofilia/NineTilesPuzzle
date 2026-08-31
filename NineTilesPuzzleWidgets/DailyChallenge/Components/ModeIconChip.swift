//
//  ModeIconChip.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A circular brand-gradient chip carrying the mode's glyph, used as the hero icon wherever the
/// original relied on a plain `Label`.
struct ModeIconChip: View {
    let icon: String
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(BrandGradient.diagonal, in: .circle)
    }
}
