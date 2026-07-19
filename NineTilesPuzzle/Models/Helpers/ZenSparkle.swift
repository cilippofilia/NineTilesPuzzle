//
//  ZenSparkle.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import SwiftUI

/// A single fleck of "magic dust" scattered around the puzzle frame when a Zen puzzle is
/// solved. Generated once per game so sparkles hold their position instead of jumping
/// around on every redraw.
struct ZenSparkle: Identifiable {
    let id = UUID()
    /// Relative to the puzzle frame, in 0...1 (slightly beyond either edge so dust can
    /// drift just outside the rounded corners).
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double

    static func makeCluster(count: Int = 10) -> [ZenSparkle] {
        (0..<count).map { index in
            ZenSparkle(
                x: .random(in: -0.05...1.05),
                y: .random(in: -0.05...1.05),
                size: .random(in: 7...16),
                color: Bool.random() ? .teal : .mint,
                delay: Double(index) * 0.1 + .random(in: 0...0.3)
            )
        }
    }
}
