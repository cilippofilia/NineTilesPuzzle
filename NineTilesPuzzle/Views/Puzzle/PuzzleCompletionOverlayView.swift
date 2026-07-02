//
//  PuzzleCompletionOverlayView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

struct PuzzleCompletionOverlayView: View {
    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings

    let completion: PuzzleCompletionViewModel
    let continueAction: () -> Void
    let dismissAction: () -> Void

    private var continueButtonLabel: String {
        guard session.isGauntletLadderMode else { return "Continue" }
        return session.isLadderRunComplete ? "New Run" : "Next Stage"
    }

    var body: some View {
        VStack {
            CompletionBannerView(
                gameMode: session.selectedGameMode,
                streak: session.currentStreakForCurrentSize,
                isNewRecord: completion.showNewRecord,
                moveCount: session.currentMoveCount,
                personalBest: session.personalBestForCurrentSize,
                elapsedTime: session.elapsedTime,
                personalBestTime: session.personalBestTimeForCurrentSize,
                isPracticeMode: settings.debugOverlayEnabled,
                timeTrialScore: session.timeTrialScore,
                personalBestScore: session.personalBestScoreForCurrentSize,
                isNewTimeTrialScoreRecord: completion.showNewTimeTrialScoreRecord,
                isLadderMode: session.isGauntletLadderMode,
                isLadderRunComplete: session.isLadderRunComplete,
                lastClearedLadderStage: session.lastClearedLadderStage,
                ladderCumulativeScore: session.ladderCumulativeScore,
                bestLadderScoreOverall: session.bestLadderScoreOverall,
                isNewLadderScoreRecord: completion.showNewLadderScoreRecord
            )
            .padding(.top)
            .padding(.horizontal)
            .offset(x: completion.bannerOffset.width, y: (completion.showCompletion ? 0 : -300) + completion.bannerOffset.height)
            .opacity(completion.showCompletion ? 1 : 0)
            .gesture(
                DragGesture()
                    .onChanged { value in completion.updateBannerDrag(value.translation) }
                    .onEnded { _ in completion.endBannerDrag() }
            )

            if completion.showCompletion && completion.hasNewBestBadge(selectedGameMode: session.selectedGameMode) {
                NewBestBadgesView(
                    showsStreak: session.selectedGameMode != .slide && session.selectedGameMode != .limitedMoves,
                    moveCount: session.currentMoveCount,
                    isNewMovesRecord: completion.showNewMovesRecord,
                    elapsedTime: session.elapsedTime,
                    isNewBestTime: completion.showNewBestTime,
                    isNewTimeTrialScoreRecord: completion.showNewTimeTrialScoreRecord,
                    timeTrialScore: session.timeTrialScore,
                    isNewLadderScoreRecord: completion.showNewLadderScoreRecord,
                    ladderCumulativeScore: session.ladderCumulativeScore,
                    isNewLadderStageRecord: completion.showNewLadderStageRecord,
                    ladderStageReached: session.lastClearedLadderStage
                )
                .padding(.horizontal)
                .offset(completion.bannerOffset)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            if session.isDailyGameActive {
                Button("Back to Menu", action: dismissAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                    .offset(y: completion.showCompletion ? 0 : 300)
                    .opacity(completion.showCompletion ? 1 : 0)
            } else {
                Button(continueButtonLabel, action: continueAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                    .offset(y: completion.showCompletion ? 0 : 300)
                    .opacity(completion.showCompletion ? 1 : 0)
            }
        }
        .allowsHitTesting(completion.showCompletion)
    }
}
