//
//  CompletionBannerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct CompletionBannerView: View {
    let gameMode: GameMode
    let streak: Int
    let isNewRecord: Bool
    let moveCount: Int
    let personalBest: Int?
    let elapsedTime: TimeInterval
    let personalBestTime: TimeInterval?
    let isPracticeMode: Bool
    let timeTrialScore: Int
    let personalBestScore: Int?
    let isNewTimeTrialScoreRecord: Bool
    // Defaulted (unlike the rest of this view's params) so the existing PuzzleView call
    // site keeps compiling until the go-live wiring step threads these through.
    var isLadderMode: Bool = false
    var isLadderRunComplete: Bool = false
    var lastClearedLadderStage: Int = 0
    var ladderCumulativeScore: Int = 0
    var bestLadderScoreOverall: Int = 0
    var isNewLadderScoreRecord: Bool = false

    private static let goldColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    /// A streak of consecutive correct placements isn't meaningful in Slide, Time Trial, or
    /// Limited Moves (see `PuzzleStatusBarView`); the banner shows elapsed time/score there
    /// instead.
    private var showsStreak: Bool { gameMode != .slide && gameMode != .timeTrial && gameMode != .limitedMoves }
    private var showsScore: Bool { gameMode == .timeTrial && !isLadderMode }
    private var showsLadderScore: Bool { gameMode == .timeTrial && isLadderMode }

    /// "Completed!" for every non-ladder solve; a mid-run ladder clear instead names the
    /// stage just cleared, and the final stage gets its own celebratory title.
    private var titleText: String {
        guard isLadderMode else { return "Completed!" }
        return isLadderRunComplete ? "Gauntlet Complete!" : "Stage \(lastClearedLadderStage) Cleared!"
    }

    var body: some View {
        VStack(spacing: 6) {
            if (isNewRecord && showsStreak) || (isNewTimeTrialScoreRecord && showsScore) || (isNewLadderScoreRecord && showsLadderScore) {
                Label(isLadderMode && isLadderRunComplete ? "New Best Run!" : "New Record!", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
            }
            Text(titleText)
                .font(.largeTitle)
                .bold()

            if !isPracticeMode {
                HStack(spacing: 20) {
                    if showsStreak {
                        Label("\(streak)", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .bold()
                    } else if showsLadderScore {
                        Label(ladderCumulativeScore.formattedScore, systemImage: "bolt.fill")
                            .foregroundStyle(.orange)
                            .bold()
                    } else if showsScore {
                        Label(timeTrialScore.formattedScore, systemImage: "bolt.fill")
                            .foregroundStyle(.orange)
                            .bold()
                    } else {
                        Label(elapsedTime.formattedMinutesSeconds, systemImage: "clock")
                            .bold()
                    }

                    Label("\(moveCount) moves", systemImage: "arrow.left.arrow.right")
                }

                if showsStreak {
                    if let best = personalBest, best != moveCount {
                        Text("Best: \(best)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if showsLadderScore {
                    if bestLadderScoreOverall > 0 && bestLadderScoreOverall != ladderCumulativeScore {
                        Text("Best: \(bestLadderScoreOverall.formattedScore)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if showsScore {
                    if let best = personalBestScore, best != timeTrialScore {
                        Text("Best: \(best.formattedScore)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if gameMode == .limitedMoves, let best = personalBest, best != moveCount {
                    Text("Best: \(best) moves")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if let best = personalBestTime, best != elapsedTime {
                    Text("Best: \(best.formattedMinutesSeconds)")
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
        CompletionBannerView(
            gameMode: .swap,
            streak: 7,
            isNewRecord: true,
            moveCount: 23,
            personalBest: nil,
            elapsedTime: 65,
            personalBestTime: nil,
            isPracticeMode: false,
            timeTrialScore: 0,
            personalBestScore: nil,
            isNewTimeTrialScoreRecord: false,
            isLadderMode: false,
            isLadderRunComplete: false,
            lastClearedLadderStage: 0,
            ladderCumulativeScore: 0,
            bestLadderScoreOverall: 0,
            isNewLadderScoreRecord: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .slide,
            streak: 3,
            isNewRecord: false,
            moveCount: 31,
            personalBest: 23,
            elapsedTime: 47,
            personalBestTime: 52,
            isPracticeMode: false,
            timeTrialScore: 0,
            personalBestScore: nil,
            isNewTimeTrialScoreRecord: false,
            isLadderMode: false,
            isLadderRunComplete: false,
            lastClearedLadderStage: 0,
            ladderCumulativeScore: 0,
            bestLadderScoreOverall: 0,
            isNewLadderScoreRecord: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .timeTrial,
            streak: 0,
            isNewRecord: false,
            moveCount: 14,
            personalBest: nil,
            elapsedTime: 38,
            personalBestTime: nil,
            isPracticeMode: false,
            timeTrialScore: 5300,
            personalBestScore: 5000,
            isNewTimeTrialScoreRecord: true,
            isLadderMode: false,
            isLadderRunComplete: false,
            lastClearedLadderStage: 0,
            ladderCumulativeScore: 0,
            bestLadderScoreOverall: 0,
            isNewLadderScoreRecord: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .timeTrial,
            streak: 0,
            isNewRecord: false,
            moveCount: 9,
            personalBest: nil,
            elapsedTime: 22,
            personalBestTime: nil,
            isPracticeMode: false,
            timeTrialScore: 0,
            personalBestScore: nil,
            isNewTimeTrialScoreRecord: false,
            isLadderMode: true,
            isLadderRunComplete: false,
            lastClearedLadderStage: 3,
            ladderCumulativeScore: 8900,
            bestLadderScoreOverall: 21000,
            isNewLadderScoreRecord: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .timeTrial,
            streak: 0,
            isNewRecord: false,
            moveCount: 12,
            personalBest: nil,
            elapsedTime: 30,
            personalBestTime: nil,
            isPracticeMode: false,
            timeTrialScore: 0,
            personalBestScore: nil,
            isNewTimeTrialScoreRecord: false,
            isLadderMode: true,
            isLadderRunComplete: true,
            lastClearedLadderStage: 10,
            ladderCumulativeScore: 32000,
            bestLadderScoreOverall: 21000,
            isNewLadderScoreRecord: true
        )
        Spacer()
        CompletionBannerView(
            gameMode: .swap,
            streak: 0,
            isNewRecord: false,
            moveCount: 18,
            personalBest: nil,
            elapsedTime: 30,
            personalBestTime: nil,
            isPracticeMode: true,
            timeTrialScore: 0,
            personalBestScore: nil,
            isNewTimeTrialScoreRecord: false,
            isLadderMode: false,
            isLadderRunComplete: false,
            lastClearedLadderStage: 0,
            ladderCumulativeScore: 0,
            bestLadderScoreOverall: 0,
            isNewLadderScoreRecord: false
        )
    }
}
