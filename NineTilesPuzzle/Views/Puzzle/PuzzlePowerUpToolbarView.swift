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
        HStack(spacing: 16) {
            PowerUpBadgeButton(type: .peek, count: powerUpStore.count(for: .peek)) {
                session.usePeekPowerUp()
            }
            PowerUpBadgeButton(type: .autoPlace, count: powerUpStore.count(for: .autoPlace)) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = session.useAutoPlacePowerUp()
                }
            }
            PowerUpBadgeButton(type: .hint, count: powerUpStore.count(for: .hint)) {
                session.useHintPowerUp()
            }
            PowerUpBadgeButton(type: .streakFreeze, count: powerUpStore.count(for: .streakFreeze)) {
                session.useStreakFreezePowerUp()
            }
            PowerUpBadgeButton(type: .reshuffle, count: powerUpStore.count(for: .reshuffle)) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = session.useReshufflePowerUp()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .capsule)
    }
}
