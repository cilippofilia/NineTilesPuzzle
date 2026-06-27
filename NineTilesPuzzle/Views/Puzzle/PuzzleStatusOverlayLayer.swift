//
//  PuzzleStatusOverlayLayer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// `PuzzleView`'s top-floating layer: the mode-aware status bar (streak/move/time/score
/// counters) plus the per-move Time Trial delta indicator. Lives outside the layout flow so
/// it never shifts the grid's vertical center, and fades out whenever a completion or fail
/// banner takes over the screen.
struct PuzzleStatusOverlayLayer: View {
    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings

    let completion: PuzzleCompletionViewModel
    let showTimeTrialDelta: Bool

    var body: some View {
        VStack {
            PuzzleStatusBarView(
                gameMode: session.selectedGameMode,
                debugOverlayEnabled: settings.debugOverlayEnabled,
                currentStreak: session.currentStreakForCurrentSize,
                bestStreak: session.allTimeHighStreakForCurrentSize,
                timerRemaining: session.timerRemaining,
                isTimerRunning: session.isTimerRunning,
                moveCount: session.currentMoveCount,
                personalBest: session.personalBestForCurrentSize,
                elapsedTime: session.elapsedTime,
                personalBestTime: session.personalBestTimeForCurrentSize,
                timeTrialRemaining: session.timeTrialRemaining,
                timeTrialScore: session.timeTrialScoreEstimate,
                personalBestScore: session.personalBestScoreForCurrentSize,
                isLadderMode: session.isLadderMode,
                currentLadderStage: session.currentLadderStage,
                ladderCumulativeScore: session.ladderCumulativeScore,
                bestLadderScoreOverall: session.bestLadderScoreOverall,
                movesRemaining: session.limitedMovesRemaining,
                movesBudget: session.movesBudgetForCurrentSize
            )
            .frame(maxWidth: .infinity)
            .padding(.top)
            .opacity(streakVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: session.isLoading)
            .animation(.easeInOut(duration: 0.35), value: session.isPreviewing)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showCompletion)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showTimeTrialFail)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showLimitedMovesFail)

            if session.isTimeTrialMode, let delta = session.lastTimeTrialDelta {
                TimeTrialDeltaIndicatorView(delta: delta)
                    .padding(.top, 8)
                    .opacity(showTimeTrialDelta ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showTimeTrialDelta)
            }

            Spacer()
        }
    }

    private var streakVisible: Bool {
        !completion.showCompletion && !completion.showTimeTrialFail && !completion.showLimitedMovesFail
            && !session.isLoading && !session.isPreviewing && session.error == nil
    }
}
