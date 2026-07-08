//
//  FogField.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/3/26.
//

import SwiftUI

/// Shared drawing routine for the Fog Mode sparkle field — the independently-twinkling
/// particle effect that hides an unrevealed tile (matching the iMessage invisible-ink look).
/// Factored out of `FogTileOverlay` so the whole board can be drawn by a *single* grid-level
/// `Canvas` (see `PuzzleFogLayer`) instead of one `TimelineView`+`Canvas` per tile.
enum FogField {
    /// A particle's time-invariant attributes. Position/frequency/phase are derived from
    /// `sin()`-based hashes, so they're precomputed once per tile (see `makeParticles`)
    /// rather than re-derived inside every 30fps `Canvas` pass — per frame, only the one
    /// brightness oscillation below remains.
    struct Particle {
        /// Position normalized to 0...1 within the tile, so a precomputed field stays
        /// valid as its tile slides between grid cells.
        let nx: CGFloat
        let ny: CGFloat
        let freq: Float
        let phase: Float
    }

    /// Particle count for one tile covering `area` square points, capped so large tiles
    /// (small grids) don't scale into thousands of particles each.
    static func particleCount(forArea area: CGFloat) -> Int {
        min(640, Int(Float(area) / 6.875))
    }

    /// Builds one tile's deterministic particle field. `seed` keeps each tile's field
    /// distinct.
    static func makeParticles(seed: Float, count: Int) -> [Particle] {
        (0..<count).map { i in
            let fi = Float(i) + seed * 1000
            return Particle(
                nx: CGFloat(hash(fi * 127.1 + 0.5)),
                ny: CGFloat(hash(fi * 311.7 + 0.5)),
                freq: 0.6 + hash(fi * 53.9) * 2.8, // 0.6–3.4 Hz
                phase: hash(fi * 91.7)             // random start phase
            )
        }
    }

    /// Draws one tile's precomputed `particles` into `rect` for the given animation `time`.
    /// Takes any sequence so callers can pass a prefix slice of a larger pool without copying.
    static func draw(particles: some Sequence<Particle>, in rect: CGRect, context: GraphicsContext, time: Float) {
        for particle in particles {
            // Each particle oscillates independently in brightness
            let raw = (sin(time * particle.freq * .pi * 2 + particle.phase * .pi * 2) + 1) * 0.5
            let brightness = raw * raw // squared: makes twinkle snappier

            guard brightness > 0.3 else { continue }

            let alpha = Double((brightness - 0.3) / 0.7)
            let radius = CGFloat(0.25 + alpha * 0.9)
            let px = rect.minX + particle.nx * rect.width
            let py = rect.minY + particle.ny * rect.height
            let dot = CGRect(
                x: px - radius,
                y: py - radius,
                width: radius * 2,
                height: radius * 2
            )

            // Cool blue-white sparkle color
            let r = 0.55 + alpha * 0.35
            let g = 0.65 + alpha * 0.25
            let b = 0.90 + alpha * 0.10
            context.fill(
                Path(ellipseIn: dot),
                with: .color(Color(red: r, green: g, blue: b, opacity: alpha))
            )
        }
    }

    /// Pseudo-random hash — deterministic per-seed, fast, no imports needed.
    static func hash(_ n: Float) -> Float {
        let x = sin(n) * 43758.5453
        return x - floor(x)
    }
}
