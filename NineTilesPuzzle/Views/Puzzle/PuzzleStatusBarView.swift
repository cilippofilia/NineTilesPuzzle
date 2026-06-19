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

    var body: some View {
        if debugOverlayEnabled {
            Label("Practice Mode", systemImage: "eye.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .capsule)
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
        PuzzleStatusBarView(gameMode: .classic, debugOverlayEnabled: false, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38)
        PuzzleStatusBarView(gameMode: .slide, debugOverlayEnabled: false, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38)
        PuzzleStatusBarView(gameMode: .classic, debugOverlayEnabled: true, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10, elapsedTime: 42, personalBestTime: 38)
    }
}
