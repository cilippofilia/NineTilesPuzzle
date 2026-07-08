//
//  PuzzlePowerUpToolbarView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import SwiftUI

/// The power-up inventory bar shown at the bottom of `PuzzleView` while a game is active.
struct PuzzlePowerUpToolbarView: View {
    @Environment(GameSession.self) private var session
    @Environment(PowerUpStore.self) private var powerUpStore

    var body: some View {
        // Only the power-ups whose purpose actually applies to the current game mode are
        // shown — e.g. a Slide + numbers board has no image to Peek at and no locked tiles
        // for Auto-place/Re-shuffle, so those buttons are omitted rather than left to no-op.
        HStack(spacing: 16) {
            if session.isPowerUpApplicable(.peek) {
                PowerUpBadgeButton(type: .peek, count: powerUpStore.count(for: .peek)) {
                    session.usePeekPowerUp()
                }
            }
            if session.isPowerUpApplicable(.autoPlace) {
                PowerUpBadgeButton(type: .autoPlace, count: powerUpStore.count(for: .autoPlace)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        _ = session.useAutoPlacePowerUp()
                    }
                }
            }
            if session.isPowerUpApplicable(.hint) {
                PowerUpBadgeButton(type: .hint, count: powerUpStore.count(for: .hint)) {
                    session.useHintPowerUp()
                }
            }
            if session.isPowerUpApplicable(.streakFreeze) {
                PowerUpBadgeButton(type: .streakFreeze, count: powerUpStore.count(for: .streakFreeze)) {
                    session.useStreakFreezePowerUp()
                }
            }
            if session.isPowerUpApplicable(.reshuffle) {
                PowerUpBadgeButton(type: .reshuffle, count: powerUpStore.count(for: .reshuffle)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        _ = session.useReshufflePowerUp()
                    }
                }
            }
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let powerUps = PowerUpStore()
    powerUps.earn(.peek, amount: 2)
    powerUps.earn(.autoPlace, amount: 1)
    powerUps.earn(.hint, amount: 3)
    powerUps.earn(.reshuffle, amount: 1)

    return PuzzlePowerUpToolbarView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: powerUps))
        .environment(powerUps)
}
