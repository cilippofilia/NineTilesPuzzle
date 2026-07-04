//
//  StatBadge.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// A small pill pairing an icon with a value, used for the move count and elapsed time.
struct StatBadge: View {
    let icon: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(accent)
            Text(text)
                .font(.subheadline.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white.opacity(0.12), in: .capsule)
    }
}
