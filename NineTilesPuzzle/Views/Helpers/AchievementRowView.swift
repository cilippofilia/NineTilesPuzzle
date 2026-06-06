//
//  AchievementRowView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementRowView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.systemImage)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? .blue : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(achievement.isUnlocked ? Color.green : Color.secondary.opacity(0.4))
                .font(achievement.isUnlocked ? .body : .caption)
        }
    }
}

#Preview {
    List {
        AchievementRowView(achievement: Achievement(id: "firstSolve", title: "First Solve", description: "Complete your first puzzle", systemImage: "puzzlepiece.fill", isUnlocked: true))
        AchievementRowView(achievement: Achievement(id: "streak10", title: "On a Roll", description: "Reach a streak of 10", systemImage: "arrow.up.circle.fill", isUnlocked: false))
    }
}
