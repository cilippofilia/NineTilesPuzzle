//
//  PuzzleStatusBarView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import SwiftUI

/// Shows the streak and move counters during normal play, or a "Practice Mode" badge
/// when the tile-index overlay is enabled, since progress isn't tracked in that mode.
/// Slide mode shows only the move counter: a streak of consecutive correct placements
/// isn't a meaningful metric when sliding tiles in and out of place is normal mid-solve.
struct PuzzleStatusBarView: View {
    let gameMode: GameMode
    let debugOverlayEnabled: Bool
    let currentStreak: Int
    let bestStreak: Int
    let timerRemaining: Double
    let isTimerRunning: Bool
    let moveCount: Int
    let personalBest: Int?
    let elapsedTime: TimeInterval
    let personalBestTime: TimeInterval?
    let timeTrialRemaining: Double
    let timeTrialScore: Int
    let personalBestScore: Int?
    let isLadderMode: Bool
    let currentLadderStage: Int
    let ladderCumulativeScore: Int
    let bestLadderScoreOverall: Int
    let movesRemaining: Int
    let movesBudget: Int

    var body: some View {
        if debugOverlayEnabled {
            Label("Practice Mode", systemImage: "eye.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .capsule)
        } else if gameMode == .timeTrial {
            VStack(spacing: 6) {
                if isLadderMode {
                    GauntletStageIndicatorView(stage: currentLadderStage, totalStages: GauntletLadderRules.stageCount)
                }
                HStack {
                    TimeTrialTimerView(remaining: timeTrialRemaining)
                        .padding(.leading)
                    Spacer()
                    if isLadderMode {
                        TimeTrialScoreView(score: ladderCumulativeScore, personalBest: bestLadderScoreOverall > 0 ? bestLadderScoreOverall : nil)
                            .padding(.trailing)
                    } else {
                        TimeTrialScoreView(score: timeTrialScore, personalBest: personalBestScore)
                            .padding(.trailing)
                    }
                }
            }
        } else if gameMode == .limitedMoves {
            HStack {
                LimitedMovesCounterView(remaining: movesRemaining, budget: movesBudget)
                    .padding(.leading)
                Spacer()
                MoveCounterView(moves: moveCount, personalBest: personalBest)
                    .padding(.trailing)
            }
        } else if gameMode == .slide {
            HStack {
                TimeCounterView(elapsed: elapsedTime, personalBest: personalBestTime)
                    .padding(.leading)
                Spacer()
                MoveCounterView(moves: moveCount, personalBest: personalBest)
                    .padding(.trailing)
            }
        } else {
            HStack {
                StreakCounterView(currentStreak: currentStreak, bestStreak: bestStreak, timerRemaining: timerRemaining, isTimerRunning: isTimerRunning)
                    .padding(.leading)
                Spacer()
                MoveCounterView(moves: moveCount, personalBest: personalBest)
                    .padding(.trailing)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PuzzleStatusBarView(gameMode: .classic, debugOverlayEnabled: false, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 45, timeTrialScore: 0, personalBestScore: nil, isLadderMode: false, currentLadderStage: 1, ladderCumulativeScore: 0, bestLadderScoreOverall: 0, movesRemaining: 0, movesBudget: 0)
        PuzzleStatusBarView(gameMode: .slide, debugOverlayEnabled: false, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 45, timeTrialScore: 0, personalBestScore: nil, isLadderMode: false, currentLadderStage: 1, ladderCumulativeScore: 0, bestLadderScoreOverall: 0, movesRemaining: 0, movesBudget: 0)
        PuzzleStatusBarView(gameMode: .timeTrial, debugOverlayEnabled: false, currentStreak: 0, bestStreak: 0, timerRemaining: 0, isTimerRunning: false, moveCount: 8, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 18, timeTrialScore: 1900, personalBestScore: 2400, isLadderMode: false, currentLadderStage: 1, ladderCumulativeScore: 0, bestLadderScoreOverall: 0, movesRemaining: 0, movesBudget: 0)
        PuzzleStatusBarView(gameMode: .timeTrial, debugOverlayEnabled: false, currentStreak: 0, bestStreak: 0, timerRemaining: 0, isTimerRunning: false, moveCount: 14, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 32, timeTrialScore: 0, personalBestScore: nil, isLadderMode: true, currentLadderStage: 3, ladderCumulativeScore: 8900, bestLadderScoreOverall: 21000, movesRemaining: 0, movesBudget: 0)
        PuzzleStatusBarView(gameMode: .limitedMoves, debugOverlayEnabled: false, currentStreak: 0, bestStreak: 0, timerRemaining: 0, isTimerRunning: false, moveCount: 7, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 0, timeTrialScore: 0, personalBestScore: nil, isLadderMode: false, currentLadderStage: 1, ladderCumulativeScore: 0, bestLadderScoreOverall: 0, movesRemaining: 5, movesBudget: 12)
        PuzzleStatusBarView(gameMode: .classic, debugOverlayEnabled: true, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38, timeTrialRemaining: 45, timeTrialScore: 0, personalBestScore: nil, isLadderMode: false, currentLadderStage: 1, ladderCumulativeScore: 0, bestLadderScoreOverall: 0, movesRemaining: 0, movesBudget: 0)
    }
}
