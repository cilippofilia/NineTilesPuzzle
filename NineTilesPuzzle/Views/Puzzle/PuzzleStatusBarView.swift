//
//  PuzzleStatusBarView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import SwiftUI

/// Shows the streak and move counters during normal play, or a "Practice Mode" badge
/// when the tile-index overlay is enabled, since progress isn't tracked in that mode.
struct PuzzleStatusBarView: View {
    let debugOverlayEnabled: Bool
    let currentStreak: Int
    let bestStreak: Int
    let timerRemaining: Double
    let isTimerRunning: Bool
    let moveCount: Int
    let personalBest: Int?

    var body: some View {
        if debugOverlayEnabled {
            Label("Practice Mode", systemImage: "eye.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: .capsule)
        } else {
            ZStack {
                StreakCounterView(currentStreak: currentStreak, bestStreak: bestStreak, timerRemaining: timerRemaining, isTimerRunning: isTimerRunning)
                HStack {
                    Spacer()
                    MoveCounterView(moves: moveCount, personalBest: personalBest)
                        .padding(.trailing)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PuzzleStatusBarView(debugOverlayEnabled: false, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10)
        PuzzleStatusBarView(debugOverlayEnabled: true, currentStreak: 3, bestStreak: 7, timerRemaining: 20, isTimerRunning: true, moveCount: 12, personalBest: 10)
    }
}
