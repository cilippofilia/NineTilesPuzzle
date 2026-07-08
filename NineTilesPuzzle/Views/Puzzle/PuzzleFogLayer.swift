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
/// Each tile's particle field is precomputed in `init` (so it's rebuilt at most once per
/// move, when the parent re-evaluates) rather than re-derived inside every 30fps `Canvas`
/// pass — per frame, only each particle's brightness oscillation is evaluated.
///
/// The per-tile blur and black scrim still live in `TileView`, which correctly tracks the
/// transient drag/frosted-glass state; this layer only paints the sparkle field over the
/// cells of tiles that are currently unrevealed and not being dragged.
struct PuzzleFogLayer: View {
    let tiles: [TileModel]
    let gridSize: Int
    let tileSize: CGFloat
    let draggingTileID: Int?

    /// Precomputed particle fields keyed by tile id. Locked tiles are skipped — they never
    /// unlock again, so their fields would go unused.
    private let particleFields: [Int: [FogField.Particle]]

    init(tiles: [TileModel], gridSize: Int, tileSize: CGFloat, draggingTileID: Int?) {
        self.tiles = tiles
        self.gridSize = gridSize
        self.tileSize = tileSize
        self.draggingTileID = draggingTileID
        let count = FogField.particleCount(forArea: tileSize * tileSize)
        self.particleFields = Dictionary(uniqueKeysWithValues: tiles.compactMap { tile in
            tile.isLocked ? nil : (tile.id, FogField.makeParticles(seed: Float(tile.id), count: count))
        })
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            Canvas { context, _ in
                let time = Float(timeline.date.timeIntervalSince1970)
                for tile in tiles where !tile.isLocked && tile.id != draggingTileID {
                    guard let particles = particleFields[tile.id] else { continue }
                    let col = tile.currentIndex % gridSize
                    let row = tile.currentIndex / gridSize
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    FogField.draw(particles: particles, in: rect, context: context, time: time)
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
