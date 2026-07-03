//
//  PuzzleFogLayer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/3/26.
//

import SwiftUI

/// Draws the Fog Mode sparkles for the whole board in a *single* `TimelineView` + `Canvas`,
/// replacing the previous one-overlay-per-tile approach (which spun up an independent 60fps
/// animation timeline and particle loop for every unrevealed tile). One layer, one loop,
/// capped at 30fps — the twinkle reads identically while doing a fraction of the work.
///
/// The per-tile blur and black scrim still live in `TileView`, which correctly tracks the
/// transient drag/frosted-glass state; this layer only paints the sparkle field over the
/// cells of tiles that are currently unrevealed and not being dragged.
struct PuzzleFogLayer: View {
    let tiles: [TileModel]
    let gridSize: Int
    let tileSize: CGFloat
    let draggingTileID: Int?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            Canvas { context, _ in
                let time = Float(timeline.date.timeIntervalSince1970)
                for tile in tiles where !tile.isLocked && tile.id != draggingTileID {
                    let col = tile.currentIndex % gridSize
                    let row = tile.currentIndex / gridSize
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    FogField.draw(in: rect, context: context, seed: Float(tile.id), time: time)
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
