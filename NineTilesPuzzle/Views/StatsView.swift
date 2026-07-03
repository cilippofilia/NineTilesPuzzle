//
//  StatsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

/// Push-navigation destination — wrap in NavigationStack only in previews.
struct StatsView: View {
    @Environment(GameSession.self) private var session
    @Environment(StatsStore.self) private var statsStore

    /// The modes shown in the personal-bests breakdown — a constant, so it's computed once
    /// rather than re-filtering `GameMode.allCases` on every render.
    private static let displayedModes = GameMode.allCases.filter { $0.isAvailable && $0 != .zen }

    var body: some View {
        List {
            Section("Streaks") {
                LabeledContent("Current Streak") {
                    Text(session.currentStreakForCurrentSize > 0 ? "\(session.currentStreakForCurrentSize)" : "--")
                        .foregroundStyle(session.currentStreakForCurrentSize > 0 ? .primary : .secondary)
                }
                LabeledContent("Best Streak") {
                    Text(session.allTimeHighStreakForCurrentSize > 0 ? "\(session.allTimeHighStreakForCurrentSize)" : "--")
                        .foregroundStyle(session.allTimeHighStreakForCurrentSize > 0 ? .primary : .secondary)
                }
            }

            ForEach(Self.displayedModes) { mode in
                Section("Personal Bests · \(mode.title)") {
                    ForEach(3...8, id: \.self) { size in
                        let key = StatsKey(gridSize: size, gameMode: mode)
                        LabeledContent(difficultyLabel(for: size)) {
                            if mode == .timeTrial {
                                let best = statsStore.personalBestScore[key]
                                Text(best.map { "\($0) pts" } ?? "--")
                                    .foregroundStyle(best != nil ? .primary : .secondary)
                            } else {
                                let best = statsStore.personalBestMoves[key]
                                Text(best.map { "\($0) moves" } ?? "--")
                                    .foregroundStyle(best != nil ? .primary : .secondary)
                            }
                        }
                    }
                }
            }

            Section("Games Played") {
                ForEach(3...8, id: \.self) { size in
                    let count = statsStore.gamesPlayedCount(forSize: size)
                    LabeledContent(difficultyLabel(for: size)) {
                        Text(count > 0 ? "\(count)" : "--")
                            .foregroundStyle(count > 0 ? .primary : .secondary)
                    }
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension StatsView {
    func difficultyLabel(for size: Int) -> String {
        switch size {
        case 3: "Easy (3×3)"
        case 4: "Medium (4×4)"
        case 5: "Hard (5×5)"
        case 6: "Expert (6×6)"
        case 7: "Master (7×7)"
        default: "Insane (8×8)"
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    NavigationStack {
        StatsView()
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore()))
            .environment(stats)
    }
}
