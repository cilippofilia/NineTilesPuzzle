//
//  WallOfFameEmptySlot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// A placeholder for a slot on the Wall of Fame that has not yet been earned.
/// Renders a dashed rounded-rect border so the board feels like something to fill in.
struct WallOfFameEmptySlot: View {
    let slot: WallOfFameSlot

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(
                Color.white.opacity(0.25),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .frame(width: 160, height: 192)
            .overlay(alignment: .bottom) {
                Text(slot.displayTitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
            }
    }
}
