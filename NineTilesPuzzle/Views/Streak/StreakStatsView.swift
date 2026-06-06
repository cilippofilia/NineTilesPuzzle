//
//  StreakStatsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct StreakStatsView: View {
    let currentStreak: Int
    let allTimeHigh: Int

    var body: some View {
        HStack {
            statItem(
                value: currentStreak,
                label: "Current streak",
                icon: "flame.fill",
                activeColor: .orange
            )

            Divider()

            statItem(
                value: allTimeHigh,
                label: "Best streak",
                icon: "trophy.fill",
                activeColor: Color(hue: 0.12, saturation: 0.9, brightness: 0.85)
            )
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 20))
    }
}

private extension StreakStatsView {
    func statItem(
        value: Int,
        label: String,
        icon: String,
        activeColor: Color
    ) -> some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(value > 0 ? activeColor : .secondary)
                Text("\(value)")
                    .foregroundStyle(.primary)
            }
            .font(.system(.title2, weight: .heavy))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakStatsView(currentStreak: 12, allTimeHigh: 47)
        StreakStatsView(currentStreak: 0, allTimeHigh: 0)
    }
}
