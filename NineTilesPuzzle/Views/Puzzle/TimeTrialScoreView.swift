//
//  TimeTrialScoreView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// Time Trial's live score estimate — "what you'd score if you solved right now" — plus
/// the personal best for the current grid size, mirroring `MoveCounterView`'s layout.
struct TimeTrialScoreView: View {
    let score: Int
    var personalBest: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.secondary)
            Text(score.formattedScore)
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())
            if let best = personalBest {
                Text("/ \(best.formattedScore)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: score)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: personalBest)
    }
}

#Preview {
    VStack(spacing: 16) {
        TimeTrialScoreView(score: 0)
        TimeTrialScoreView(score: 4200, personalBest: 5000)
        TimeTrialScoreView(score: 5300, personalBest: 5000)
    }
}
