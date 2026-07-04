//
//  ProgressBar.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// A slim horizontal fill of the board's completion, spanning the width it's given. The linear
/// counterpart to `ProgressRing`, used as the Dynamic Island's expanded-view anchor element.
/// Hand-rolled from capsules with a fixed height rather than a `Gauge` — the gauge's intrinsic
/// sizing pushed its rounded ends into the Dynamic Island's bottom curve and got clipped.
struct ProgressBar: View {
    /// Fraction solved, 0...1.
    let progress: Double
    let accent: Color
    var height: CGFloat = 8

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.15))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(accent.gradient)
                        // Floor at `height` so a nearly-empty board still shows a rounded nub
                        // rather than an invisible sliver.
                        .frame(width: max(height, proxy.size.width * clamped))
                }
            }
    }
}
