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
    let seed: Float

    /// Upper-bound particle pool, precomputed once. The rendered size isn't known until
    /// the `Canvas` closure runs, so `body` draws only the pool prefix matching the actual
    /// area's density budget — positions are normalized, so a prefix stays deterministic.
    private let particles: [FogField.Particle]

    init(seed: Float = 0) {
        self.seed = seed
        // A single large surface (the full preview card, not one tile), so it gets a
        // bigger budget than `FogField.particleCount`'s per-tile cap.
        self.particles = FogField.makeParticles(seed: seed, count: 2000)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            Canvas { context, size in
                let budget = min(particles.count, Int(Float(size.width * size.height) / 6.875))
                FogField.draw(
                    particles: particles.prefix(budget),
                    in: CGRect(origin: .zero, size: size),
                    context: context,
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
