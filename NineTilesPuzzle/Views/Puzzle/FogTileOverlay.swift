//
//  FogTileOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import SwiftUI

/// Animated sparkle overlay rendered on top of unrevealed Fog Mode tiles.
/// Independently-twinkling particles, each oscillating in brightness at its own
/// frequency — matching the iMessage invisible-ink effect. Drawn over a blurred,
/// darkened version of the tile image rather than a solid background.
struct FogTileOverlay: View {
    var seed: Float = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                drawFog(context: context, size: size, time: Float(timeline.date.timeIntervalSince1970))
            }
        }
    }

    private func drawFog(context: GraphicsContext, size: CGSize, time: Float) {
        let area = Float(size.width * size.height)
        let count = max(640, Int(area / 6.875))

        for i in 0..<count {
            let fi = Float(i) + seed * 1000

            let px = CGFloat(hash(fi * 127.1 + 0.5)) * size.width
            let py = CGFloat(hash(fi * 311.7 + 0.5)) * size.height

            // Each particle oscillates independently in brightness
            let freq = 0.6 + hash(fi * 53.9) * 2.8 // 0.6–3.4 Hz
            let phase = hash(fi * 91.7) // random start phase
            let raw = (sin(time * freq * .pi * 2 + phase * .pi * 2) + 1) * 0.5
            let brightness = raw * raw // squared: makes twinkle snappier

            guard brightness > 0.3 else { continue }

            let alpha = Double((brightness - 0.3) / 0.7)
            let radius = CGFloat(0.25 + alpha * 0.9)
            let rect = CGRect(
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
                Path(ellipseIn: rect),
                with: .color(Color(red: r, green: g, blue: b, opacity: alpha))
            )
        }
    }

    /// Pseudo-random hash — deterministic per-seed, fast, no imports needed.
    private func hash(_ n: Float) -> Float {
        let x = sin(n) * 43758.5453
        return x - floor(x)
    }
}

#Preview {
    FogTileOverlay()
        .frame(width: 100, height: 100)
        .clipShape(.rect(cornerRadius: 6))
}
