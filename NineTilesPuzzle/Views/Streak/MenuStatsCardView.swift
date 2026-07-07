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
                leftValue: session.bestLadderScoreOverall > 0 ? session.bestLadderScoreOverall.formattedScore : "--",
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
                leftValue: session.personalBestScoreForCurrentSize.map { $0.formattedScore } ?? "--",
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
            threeStatCard(
                leftValue: "\(session.currentStreakForCurrentSize)",
                leftLabel: "Current streak",
                leftIcon: "flame.fill",
                leftColor: session.currentStreakForCurrentSize > 0 ? .orange : .secondary,
                midValue: "\(session.allTimeHighStreakForCurrentSize)",
                midLabel: "Best streak",
                midIcon: "trophy.fill",
                midColor: session.allTimeHighStreakForCurrentSize > 0
                    ? Color(hue: 0.12, saturation: 0.9, brightness: 0.85) : .secondary,
                rightValue: session.personalBestForCurrentSize.map { "\($0)" } ?? "--",
                rightLabel: "Best moves",
                rightIcon: "arrow.left.arrow.right",
                rightColor: session.personalBestForCurrentSize != nil ? .primary : .secondary
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
        .padding(.vertical, 10)
        .padding(.horizontal)
    }

    func threeStatCard(
        leftValue: String, leftLabel: String, leftIcon: String, leftColor: Color,
        midValue: String, midLabel: String, midIcon: String, midColor: Color,
        rightValue: String, rightLabel: String, rightIcon: String, rightColor: Color
    ) -> some View {
        HStack {
            statItem(value: leftValue, label: leftLabel, icon: leftIcon, color: leftColor)
            Divider()
            statItem(value: midValue, label: midLabel, icon: midIcon, color: midColor)
            Divider()
            statItem(value: rightValue, label: rightLabel, icon: rightIcon, color: rightColor)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }

    func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(value == "--" ? .secondary : color)
                Text(value)
                    .foregroundStyle(value == "--" ? .secondary : .primary)
            }
            .font(.system(.headline, weight: .bold))
            Text(label)
                .font(.caption2)
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
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: PowerUpStore()))
    }
    .padding()
}
