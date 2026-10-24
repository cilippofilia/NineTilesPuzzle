//
//  PuzzleSidePanelStatsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import SwiftUI

/// The side panel's stat rows: live while playing, the comparison against the player's
/// bests once solved. Reads the session's per-second fields (`elapsedTime`, the
/// countdowns) on its own, so a stopwatch tick only re-evaluates these rows instead of
/// the whole panel.
struct PuzzleSidePanelStatsView: View {
    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings

    let completion: PuzzleCompletionViewModel
    let showTimeTrialDelta: Bool

    /// Mirrors `PuzzleStatusBarView`: Slide, Daily and Challenge games never accrue a live
    /// streak (Time Trial and Limited Moves show their own countdowns instead).
    private var showsLiveStreak: Bool {
        session.selectedGameMode != .slide && !session.isDailyGameActive && !session.isChallengeGameActive
    }

    private var rows: [CompletionStatRow] {
        var stats = CompletionComparison.GameStats(
            gameMode: session.selectedGameMode,
            isLadderMode: session.isGauntletLadderMode,
            isLadderRunComplete: session.isLadderRunComplete,
            moveCount: session.currentMoveCount,
            elapsedTime: session.elapsedTime,
            ladderRunScore: session.ladderCumulativeScore,
            ladderStage: session.lastClearedLadderStage
        )
        if completion.showCompletion {
            stats.timeTrialScore = session.timeTrialScore
            return CompletionComparison.rows(for: stats, bests: session.bestsBeforeSolve)
        }
        stats.timeTrialScore = session.timeTrialScoreEstimate
        return CompletionComparison.liveRows(for: stats, bests: session.rankedPersonalBests)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !completion.showCompletion {
                Group {
                    if settings.debugOverlayEnabled {
                        Label("Practice Mode", systemImage: "eye.fill")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                    } else if session.isTimeTrialMode {
                        VStack(alignment: .leading) {
                            if session.isGauntletLadderMode {
                                GauntletStageIndicatorView(
                                    stage: session.currentLadderStage,
                                    totalStages: GauntletLadderRules.stageCount
                                )
                            }
                            HStack {
                                TimeTrialTimerView(remaining: session.timeTrialRemaining)
                                if let delta = session.lastTimeTrialDelta {
                                    TimeTrialDeltaIndicatorView(delta: delta)
                                        .opacity(showTimeTrialDelta ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: showTimeTrialDelta)
                                }
                            }
                        }
                    } else if session.isLimitedMovesMode {
                        LimitedMovesCounterView(
                            remaining: session.limitedMovesRemaining,
                            budget: session.movesBudgetForCurrentSize
                        )
                    } else if showsLiveStreak {
                        StreakCounterView(
                            currentStreak: session.currentStreakForCurrentSize,
                            bestStreak: session.allTimeHighStreakForCurrentSize,
                            timerRemaining: session.timerRemaining,
                            isTimerRunning: session.isTimerRunning
                        )
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }

            ForEach(rows) { row in
                CompletionStatRowView(row: row)
            }
        }
    }
}
