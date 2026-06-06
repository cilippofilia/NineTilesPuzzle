//
//  AchievementToastView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 1) {
                Text("Achievement Unlocked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(achievement.title)
                    .font(.subheadline)
                    .bold()
            }

            Spacer()

            Image(systemName: achievement.systemImage)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
    }
}

#Preview {
    AchievementToastView(achievement: Achievement(id: "firstSolve", title: "First Solve", description: "Complete your first puzzle", systemImage: "puzzlepiece.fill", isUnlocked: true))
        .padding()
}
