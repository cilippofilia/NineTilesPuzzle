//
//  GauntletStageIndicatorView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// Shows which Gauntlet Ladder stage is currently active, above the timer/score row in
/// `PuzzleStatusBarView`. Matches the capsule-on-`.regularMaterial` style used throughout
/// the Time Trial HUD (`TimeTrialTimerView`, `TimeTrialScoreView`).
struct GauntletStageIndicatorView: View {
    let stage: Int
    let totalStages: Int

    var body: some View {
        Text("Stage \(stage) of \(totalStages)")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
    }
}

#Preview {
    GauntletStageIndicatorView(stage: 3, totalStages: GauntletLadderRules.stageCount)
}
