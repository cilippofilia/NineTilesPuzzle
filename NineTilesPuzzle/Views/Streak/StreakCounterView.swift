//
//  StreakCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct StreakCounterView: View {
    let currentStreak: Int
    let bestStreak: Int
    let timerRemaining: Double
    let isTimerRunning: Bool

    private static let trophyColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(currentStreak > 0 ? .orange : .secondary)
                Text("\(currentStreak)")
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            if isTimerRunning {
                Divider()
                    .frame(height: 16)

                TimerCountdownView(remaining: timerRemaining)

                Divider()
                    .frame(height: 16)
            } else {
                Divider()
                    .frame(height: 16)
            }

            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(bestStreak > 0 ? Self.trophyColor : .secondary)
                Text("\(bestStreak)")
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStreak)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bestStreak)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTimerRunning)
    }
}

private struct TimerCountdownView: View {
    let remaining: Double

    private var seconds: Int { Int(remaining.rounded(.up)) }

    private var color: Color {
        if remaining > 15 { return .primary }
        if remaining > 7 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .foregroundStyle(color)
            Text("\(seconds)")
                .bold()
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: true))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: seconds)
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakCounterView(currentStreak: 0, bestStreak: 0, timerRemaining: 30, isTimerRunning: false)
        StreakCounterView(currentStreak: 5, bestStreak: 12, timerRemaining: 18, isTimerRunning: true)
        StreakCounterView(currentStreak: 42, bestStreak: 42, timerRemaining: 5, isTimerRunning: true)
    }
}
