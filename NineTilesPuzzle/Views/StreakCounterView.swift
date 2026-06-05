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

            Divider()
                .frame(height: 16)

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
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakCounterView(currentStreak: 0, bestStreak: 0)
        StreakCounterView(currentStreak: 5, bestStreak: 12)
        StreakCounterView(currentStreak: 42, bestStreak: 42)
    }
}
