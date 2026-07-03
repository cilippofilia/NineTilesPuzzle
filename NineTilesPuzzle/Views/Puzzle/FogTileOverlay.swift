//
//  FogTileOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import SwiftUI

/// Standalone animated sparkle overlay for a single element — used by the Fog Mode
/// preview card (`ImagePreviewView`). During actual play the board's sparkles are drawn
/// by one shared grid-level `PuzzleFogLayer` rather than one overlay per tile; both share
/// the same particle math via `FogField`.
struct FogTileOverlay: View {
    var seed: Float = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                FogField.draw(
                    in: CGRect(origin: .zero, size: size),
                    context: context,
                    seed: seed,
                    time: Float(timeline.date.timeIntervalSince1970)
                )
            }
        }
    }
}

#Preview {
    FogTileOverlay()
        .frame(width: 100, height: 100)
        .clipShape(.rect(cornerRadius: 6))
}
