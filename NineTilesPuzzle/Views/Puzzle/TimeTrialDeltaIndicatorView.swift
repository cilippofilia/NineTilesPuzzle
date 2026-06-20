//
//  TimeTrialDeltaIndicatorView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// A small "+1s"/"-2s" pill reflecting the combo bonus or misplay penalty from the most
/// recent move. Purely presentational — visibility/auto-dismiss timing is owned by the
/// caller (`PuzzleView`), matching the existing achievement-toast pattern.
struct TimeTrialDeltaIndicatorView: View {
    let delta: TimeInterval

    private var isBonus: Bool { delta > 0 }

    var body: some View {
        Label(
            "\(isBonus ? "+" : "")\(Int(delta))s",
            systemImage: isBonus ? "plus.circle.fill" : "minus.circle.fill"
        )
        .font(.subheadline.bold())
        .foregroundStyle(isBonus ? .green : .red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
    }
}

#Preview {
    VStack(spacing: 16) {
        TimeTrialDeltaIndicatorView(delta: 1)
        TimeTrialDeltaIndicatorView(delta: -2)
    }
}
