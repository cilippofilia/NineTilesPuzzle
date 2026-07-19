//
//  GameModeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import SwiftUI

struct GameModeView: View {
    @Environment(GameSession.self) private var session
    @Environment(StoreManager.self) private var store
    @State private var paywallContext: PaywallContext?

    var body: some View {
        List {
            ForEach(GameMode.allCases) { mode in
                if mode.isAvailable {
                    let isLocked = PremiumFeature.gameMode(mode).isLocked(isPremiumUnlocked: store.isPremiumUnlocked)
                    Button {
                        if isLocked {
                            paywallContext = .gameMode(mode)
                        } else {
                            withAnimation {
                                session.setGameMode(mode)
                            }
                        }
                    } label: {
                        GameModeRowView(mode: mode, isSelected: session.selectedGameMode == mode, isLocked: isLocked)
                    }
                    .foregroundStyle(.primary)
                } else {
                    GameModeRowView(mode: mode, isSelected: false)
                        .foregroundStyle(.secondary)
                }

                if mode == .timeTrial && session.selectedGameMode == .timeTrial {
                    HStack {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Gauntlet Ladder")
                                Text("10 escalating stages with fixed grid sizes. Difficulty is set automatically while active.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "figure.stairs")
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Toggle("Gauntlet Ladder", isOn: Binding(
                            get: { session.isLadderMode },
                            set: { session.setLadderMode($0) }
                        ))
                        .labelsHidden()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .navigationTitle("Game Modes")
        .navigationBarTitleDisplayMode(.inline)
        .paywallSheet(context: $paywallContext)
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    NavigationStack {
        GameModeView()
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: PowerUpStore(), challengeStore: ChallengeStore()))
            .environment(StoreManager())
    }
}
