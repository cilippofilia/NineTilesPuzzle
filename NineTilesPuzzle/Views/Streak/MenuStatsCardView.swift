//
//  MenuStatsCardView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// Mode-aware stats card for the main menu. Shows whatever metric is meaningful
/// for the currently selected mode and grid size. Hidden entirely in Zen mode.
struct MenuStatsCardView: View {
    @Environment(GameSession.self) private var session

    var body: some View {
        if session.selectedGameMode == .zen {
            EmptyView()
        } else if session.isGauntletLadderMode {
            twoStatCard(
                leftValue: session.bestLadderScoreOverall > 0 ? "\(session.bestLadderScoreOverall)" : "--",
                leftLabel: "Best Score",
                leftIcon: "star.fill",
                leftColor: .yellow,
                rightValue: session.bestLadderStageReachedOverall > 0
                    ? "\(session.bestLadderStageReachedOverall) / \(GauntletLadderRules.stageCount)"
                    : "--",
                rightLabel: "Best Stage",
                rightIcon: "figure.stairs",
                rightColor: .primary
            )
        } else if session.isTimeTrialMode {
            twoStatCard(
                leftValue: session.personalBestScoreForCurrentSize.map { "\($0)" } ?? "--",
                leftLabel: "Best Score",
                leftIcon: "star.fill",
                leftColor: .yellow,
                rightValue: session.personalBestForCurrentSize.map { "\($0)" } ?? "--",
                rightLabel: "Best Moves",
                rightIcon: "arrow.left.arrow.right",
                rightColor: .primary
            )
        } else if session.isLimitedMovesMode {
            twoStatCard(
                leftValue: session.personalBestForCurrentSize.map { "\($0)" } ?? "--",
                leftLabel: "Best Moves",
                leftIcon: "arrow.left.arrow.right",
                leftColor: .primary,
                rightValue: session.personalBestTimeForCurrentSize?.formattedMinutesSeconds ?? "--",
                rightLabel: "Best Time",
                rightIcon: "clock.fill",
                rightColor: .blue
            )
        } else {
            StreakStatsView(
                currentStreak: session.currentStreakForCurrentSize,
                allTimeHigh: session.allTimeHighStreakForCurrentSize,
                personalBestMoves: session.personalBestForCurrentSize
            )
        }
    }
}

private extension MenuStatsCardView {
    func twoStatCard(
        leftValue: String, leftLabel: String, leftIcon: String, leftColor: Color,
        rightValue: String, rightLabel: String, rightIcon: String, rightColor: Color
    ) -> some View {
        HStack {
            statItem(value: leftValue, label: leftLabel, icon: leftIcon, color: leftColor)
            Divider()
            statItem(value: rightValue, label: rightLabel, icon: rightIcon, color: rightColor)
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 20))
    }

    func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(value == "--" ? .secondary : color)
                Text(value)
                    .foregroundStyle(value == "--" ? .secondary : .primary)
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
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    VStack(spacing: 16) {
        MenuStatsCardView()
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings))
    }
    .padding()
}
