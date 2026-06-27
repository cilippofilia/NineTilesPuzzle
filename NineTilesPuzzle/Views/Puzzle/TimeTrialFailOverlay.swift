//
//  TimeTrialFailOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// The Time Trial fail overlay shown when the countdown reaches zero unsolved, including the
/// extra ladder context (stage reached, cumulative score) when running the Gauntlet ladder.
struct TimeTrialFailOverlay: View {
    @Environment(GameSession.self) private var session

    let completion: PuzzleCompletionViewModel
    let onTryAgain: () -> Void

    var body: some View {
        PuzzleFailOverlayView(isShowing: completion.showTimeTrialFail, onTryAgain: onTryAgain) {
            TimeTrialFailView(
                moveCount: session.currentMoveCount,
                personalBestScore: session.personalBestScoreForCurrentSize,
                isLadderMode: session.isGauntletLadderMode,
                ladderStageReached: session.currentLadderStage,
                ladderCumulativeScore: session.ladderCumulativeScore,
                bestLadderStageReachedOverall: session.bestLadderStageReachedOverall
            )
        }
    }
}
