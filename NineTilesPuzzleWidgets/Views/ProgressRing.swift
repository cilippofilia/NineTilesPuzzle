//
//  ProgressRing.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// A compact circular progress indicator for the Dynamic Island's compact-trailing and minimal
/// slots, showing how many tiles are already home as a ring that fills toward a solved board.
struct ProgressRing: View {
    /// Fraction solved, 0...1.
    let progress: Double
    let accent: Color
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                // A hair of trim so an untouched board still shows a dot rather than nothing.
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        // The stroke is centered on the circle's path, so half of it sits outside the frame;
        // without this inset that overflow gets clipped by the Dynamic Island's curved edge.
        .padding(lineWidth / 2)
    }
}
