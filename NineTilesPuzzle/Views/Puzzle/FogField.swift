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
    /// Draws one tile's worth of sparkles into `rect` for the given animation `time`.
    /// `seed` keeps each tile's particle field deterministic and distinct.
    static func draw(in rect: CGRect, context: GraphicsContext, seed: Float, time: Float) {
        let area = Float(rect.width * rect.height)
        let count = max(640, Int(area / 6.875))

        for i in 0..<count {
            let fi = Float(i) + seed * 1000

            let px = rect.minX + CGFloat(hash(fi * 127.1 + 0.5)) * rect.width
            let py = rect.minY + CGFloat(hash(fi * 311.7 + 0.5)) * rect.height

            // Each particle oscillates independently in brightness
            let freq = 0.6 + hash(fi * 53.9) * 2.8 // 0.6–3.4 Hz
            let phase = hash(fi * 91.7) // random start phase
            let raw = (sin(time * freq * .pi * 2 + phase * .pi * 2) + 1) * 0.5
            let brightness = raw * raw // squared: makes twinkle snappier

            guard brightness > 0.3 else { continue }

            let alpha = Double((brightness - 0.3) / 0.7)
            let radius = CGFloat(0.25 + alpha * 0.9)
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
