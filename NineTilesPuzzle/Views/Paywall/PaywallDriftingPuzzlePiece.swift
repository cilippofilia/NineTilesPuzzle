//
//  PaywallDriftingPuzzlePiece.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// One faint puzzle-piece watermark in `PaywallBackgroundView`, gently bobbing and rotating
/// in a slow forever-repeating loop so the background reads as alive rather than static.
/// Each instance is given its own duration and delay so the pieces drift out of phase with
/// one another instead of moving in lockstep.
struct PaywallDriftingPuzzlePiece: View {
    let rotation: Double
    var size: CGFloat = 90
    var tint: Color = .white
    var opacity: Double = 0.045
    let alignment: Alignment
    let offsetX: CGFloat
    let offsetY: CGFloat
    let driftDuration: Double
    let driftDelay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false

    var body: some View {
        let driftX: CGFloat = isDrifting ? 12 : -12
        let driftY: CGFloat = isDrifting ? -16 : 16

        Image(systemName: "puzzlepiece.fill")
            .font(.system(size: size))
            .foregroundStyle(tint.opacity(opacity))
            .rotationEffect(.degrees(rotation + (isDrifting ? 7 : -7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .visualEffect { content, proxy in
                content.offset(
                    x: proxy.size.width * offsetX + driftX,
                    y: proxy.size.height * offsetY + driftY
                )
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: driftDuration).repeatForever(autoreverses: true).delay(driftDelay)
                ) {
                    isDrifting = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black
        PaywallDriftingPuzzlePiece(
            rotation: -18, alignment: .center, offsetX: 0, offsetY: 0, driftDuration: 7, driftDelay: 0
        )
    }
    .ignoresSafeArea()
}
