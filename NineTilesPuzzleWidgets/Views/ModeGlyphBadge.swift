//
//  ModeGlyphBadge.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// The mode's SF Symbol in a filled accent disc, tucked into a board thumbnail's bottom-trailing
/// corner. Shared by the Lock Screen card and the Dynamic Island so both read the same way; the
/// glyph, disc, and corner offset all scale from `size`.
struct ModeGlyphBadge: View {
    let icon: String
    let accent: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(accent.gradient, in: .circle)
            .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 2))
            .offset(x: size * 0.27, y: size * 0.27)
    }
}
