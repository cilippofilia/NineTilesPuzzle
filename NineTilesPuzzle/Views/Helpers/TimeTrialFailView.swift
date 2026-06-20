//
//  TimeTrialFailView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// Time Trial's "ran out the clock" overlay, shown instead of `CompletionBannerView` when
/// the countdown reaches zero before the puzzle is solved. The score is always 0 in this
/// case (the MVP formula only rewards remaining time, no partial credit), so this leads
/// with move count instead to still give the player something concrete to read.
struct TimeTrialFailView: View {
    let moveCount: Int
    let personalBestScore: Int?
    var isLadderMode: Bool = false
    var ladderStageReached: Int = 0
    var ladderCumulativeScore: Int = 0
    var bestLadderStageReachedOverall: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            Label(isLadderMode ? "Ladder Run Over" : "Out of Time", systemImage: "timer")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.red)

            if isLadderMode {
                Label("Reached Stage \(ladderStageReached) of \(GauntletLadderRules.stageCount)", systemImage: "flag.checkered")
                    .bold()
                Label("\(ladderCumulativeScore) pts", systemImage: "bolt.fill")
                    .bold()
                if bestLadderStageReachedOverall > 0 {
                    Text("Best: Stage \(bestLadderStageReachedOverall)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Label("\(moveCount) moves", systemImage: "arrow.left.arrow.right")
                    .bold()

                if let best = personalBestScore {
                    Text("Best Score: \(best)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    VStack(spacing: 20) {
        TimeTrialFailView(moveCount: 14, personalBestScore: 4200)
        TimeTrialFailView(moveCount: 3, personalBestScore: nil)
        TimeTrialFailView(
            moveCount: 0,
            personalBestScore: nil,
            isLadderMode: true,
            ladderStageReached: 4,
            ladderCumulativeScore: 11200,
            bestLadderStageReachedOverall: 7
        )
    }
}
