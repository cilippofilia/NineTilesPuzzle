//
//  AchievementRowView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementRowView: View {
    @Environment(StatsStore.self) private var statsStore
    let achievement: Achievement

    /// Non-nil for count-based achievements (≥, target > 1) that aren't yet unlocked.
    private var progressInfo: (fraction: Double, current: Int, target: Int)? {
        guard !achievement.isUnlocked,
              achievement.comparison == .greaterThanOrEqual,
              achievement.target > 1
        else { return nil }
        let value = achievement.metric.value(in: statsStore, justSolved: false, now: .now)
        return (
            fraction: min(Double(value) / Double(achievement.target), 1.0),
            current: value,
            target: achievement.target
        )
    }

    /// Non-nil for efficiency achievements (≤) that aren't yet unlocked and have a record.
    private var bestMovesText: String? {
        guard !achievement.isUnlocked,
              achievement.comparison == .lessThanOrEqual
        else { return nil }
        let value = achievement.metric.value(in: statsStore, justSolved: false, now: .now)
        guard value < Int.max else { return nil }
        return "Best: \(value) — Goal: ≤\(achievement.target)"
    }

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
                if let info = progressInfo {
                    HStack(spacing: 6) {
                        ProgressView(value: info.fraction)
                            .tint(.accentColor)
                        Text("\(info.current) / \(info.target)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.top, 2)
                } else if let text = bestMovesText {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                } else if achievement.isUnlocked, let date = achievement.unlockedDate {
                    Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(achievement.isUnlocked ? Color.green : Color.secondary.opacity(0.4))
                .font(achievement.isUnlocked ? .body : .caption)
        }
    }
}

#Preview {
    let stats = StatsStore()
    List {
        AchievementRowView(achievement: Achievement(id: "firstSolve", title: "First Solve", description: "Complete your first puzzle", systemImage: "puzzlepiece.fill", isUnlocked: true, unlockedDate: Date()))
        AchievementRowView(achievement: Achievement(id: "tenGames", title: "Dedicated", description: "Complete 10 puzzles", systemImage: "trophy.fill", category: .milestones, metric: .totalGamesPlayed, target: 10, comparison: .greaterThanOrEqual))
        AchievementRowView(achievement: Achievement(id: "streak10", title: "On a Roll", description: "Reach a streak of 10", systemImage: "arrow.up.circle.fill", category: .streaks, metric: .bestStreakOverall, target: 10, comparison: .greaterThanOrEqual))
    }
    .environment(stats)
}
