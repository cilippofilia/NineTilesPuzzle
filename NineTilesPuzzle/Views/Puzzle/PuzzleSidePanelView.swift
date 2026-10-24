//
//  PuzzleSidePanelView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import SwiftUI

/// The wide-layout panel beside the board (see `PuzzleSidePanelLayout`), on screen for the
/// whole game. While playing it replaces the floating status bar and power-up toolbar:
/// live stats beside the bests they're chasing, plus the power-ups. Once solved, the same
/// rows turn into the comparison against those bests, followed by the streak, power-ups
/// earned and any friend-challenge outcome. A Time Trial or Limited Moves loss shows here
/// too, so no button ever lands in the middle of the screen — on the fold of an iPhone Duo.
struct PuzzleSidePanelView: View {
    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings
    @Environment(PowerUpStore.self) private var powerUpStore

    let completion: PuzzleCompletionViewModel
    let isGameActive: Bool
    let showTimeTrialDelta: Bool
    let continueAction: () -> Void
    let dismissAction: () -> Void
    let tryAgainAction: () -> Void
    var rechallengeAction: (() -> Void)?
    var sendResultAction: (() -> Void)?

    private var isShowingFail: Bool {
        completion.showTimeTrialFail || completion.showLimitedMovesFail
    }

    /// Same rule as `CompletionBannerView`: a streak of correct placements isn't meaningful
    /// in Slide, Time Trial, or Limited Moves, and Daily/Challenge games never accrue one.
    private var showsStreakSummary: Bool {
        !settings.debugOverlayEnabled && !session.isDailyGameActive && !session.isChallengeGameActive
            && session.selectedGameMode != .slide && session.selectedGameMode != .timeTrial
            && session.selectedGameMode != .limitedMoves
    }

    private var subtitle: String {
        let size = "\(session.gridSize)×\(session.gridSize)"
        if session.isDailyGameActive { return "Daily Challenge · \(size)" }
        if session.isGauntletLadderMode { return "Gauntlet · \(size)" }
        return "\(session.selectedGameMode.title) · \(size)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        if completion.showCompletion {
                            Text(CompletionBannerView.title(
                                isLadderMode: session.isGauntletLadderMode,
                                isLadderRunComplete: session.isLadderRunComplete,
                                lastClearedLadderStage: session.lastClearedLadderStage
                            ))
                            .font(.largeTitle)
                            .bold()

                            Text(subtitle)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(subtitle)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .padding(.horizontal)

                    if completion.showTimeTrialFail {
                        TimeTrialFailView(
                            moveCount: session.currentMoveCount,
                            personalBestScore: session.personalBestScoreForCurrentSize,
                            isLadderMode: session.isGauntletLadderMode,
                            ladderStageReached: session.currentLadderStage,
                            ladderCumulativeScore: session.ladderCumulativeScore,
                            bestLadderStageReachedOverall: session.bestLadderStageReachedOverall
                        )
                        .frame(maxWidth: .infinity)
                    } else if completion.showLimitedMovesFail {
                        LimitedMovesFailView(
                            moveCount: session.currentMoveCount,
                            personalBestMoves: session.personalBestForCurrentSize
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        PuzzleSidePanelStatsView(completion: completion, showTimeTrialDelta: showTimeTrialDelta)
                    }

                    if completion.showCompletion {
                        if showsStreakSummary {
                            HStack {
                                Label("Streak \(session.currentStreakForCurrentSize)", systemImage: "flame.fill")
                                    .bold()
                                    .foregroundStyle(.orange)
                                Spacer()
                                Text("best \(session.allTimeHighStreakForCurrentSize)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        let earnedPowerUps = PuzzleCompletionOverlayView.earnedPowerUps(from: powerUpStore)
                        if !earnedPowerUps.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Earned")
                                    .font(.footnote)
                                    .bold()
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)

                                HStack(alignment: .top, spacing: 24) {
                                    ForEach(earnedPowerUps, id: \.type) { earned in
                                        EarnedPowerUpBadgeView(
                                            type: earned.type,
                                            amount: earned.amount,
                                            finalCount: powerUpStore.count(for: earned.type)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        if session.isChallengeGameActive, let outcome = session.challengeOutcome,
                           let challenge = session.activeChallenge {
                            ChallengeOutcomeView(
                                outcome: outcome,
                                opponentName: challenge.senderName,
                                yourMoves: session.currentMoveCount,
                                yourTime: session.elapsedTime,
                                opponentMoves: challenge.senderMoves,
                                opponentTime: challenge.senderTime,
                                onRechallenge: rechallengeAction,
                                onSendResult: sendResultAction
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)

            if isShowingFail {
                Button("Try Again", action: tryAgainAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonSizing(.flexible)
                    .padding()
            } else if completion.showCompletion {
                Group {
                    if session.isDailyGameActive {
                        Button("Back to Menu", action: dismissAction)
                    } else {
                        Button(
                            PuzzleCompletionOverlayView.continueButtonLabel(
                                isLadderMode: session.isGauntletLadderMode,
                                isLadderRunComplete: session.isLadderRunComplete
                            ),
                            action: continueAction
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonSizing(.flexible)
                .padding()
            } else if settings.powerUpsEnabled && isGameActive {
                PuzzlePowerUpToolbarView()
                    .padding()
            }
        }
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showCompletion)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isShowingFail)
    }
}
