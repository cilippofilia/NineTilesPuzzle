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
/// Each tile's particle field is precomputed once and cached in `@State`, keyed by tile id,
/// rather than rebuilt from scratch every time the parent re-evaluates (i.e. every move) —
/// tile ids never gain a field back once generated, since `FogField.makeParticles` is a pure
/// function of `(seed: tile id, count)`, so recomputing on every move regenerated identical
/// particles for every still-unrevealed tile at real (measured ~2ms/move on an 8×8 board)
/// cost. The cache is invalidated wholesale only when `tileSize` changes (grid size change,
/// rotation, layout change), since that changes the target particle count per tile.
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
    @State private var particleFields: [Int: [FogField.Particle]] = [:]
    @State private var cachedTileSize: CGFloat?

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
        .onChange(of: tiles.map(\.isLocked), initial: true) { _, _ in syncParticleFields() }
        .onChange(of: tileSize, initial: true) { _, _ in syncParticleFields() }
    }

    private func syncParticleFields() {
        if cachedTileSize != tileSize {
            particleFields = [:]
            cachedTileSize = tileSize
        }
        let count = FogField.particleCount(forArea: tileSize * tileSize)
        for tile in tiles where !tile.isLocked && particleFields[tile.id] == nil {
            particleFields[tile.id] = FogField.makeParticles(seed: Float(tile.id), count: count)
        }
    }
}
