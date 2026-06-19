//
//  AchievementsStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

@MainActor
@Observable
final class AchievementsStore {
    var achievements: [Achievement] = []
    var newlyUnlockedAchievement: Achievement?

    init() {
        loadAchievements()
    }

    func refreshAchievementsFromRemote() async {
        guard let definitions = try? await AchievementService.fetchRemote() else { return }
        achievements = definitions.map { achievement in
            var a = achievement
            a.isUnlocked = UserDefaults.standard.bool(forKey: Keys.achievement(id: achievement.id))
            return a
        }
    }

    func checkAchievements(using stats: StatsStore) {
        let totalGames = stats.gamesPlayed.values.reduce(0, +)
        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            let shouldUnlock: Bool
            switch achievements[i].id {
            case "firstSolve":        shouldUnlock = totalGames >= 1
            case "tenGames":          shouldUnlock = totalGames >= 10
            case "fiftyGames":        shouldUnlock = totalGames >= 50
            case "solveFourByFour":   shouldUnlock = stats.gamesPlayedCount(forSize: 4) >= 1
            case "solveFiveByFive":   shouldUnlock = stats.gamesPlayedCount(forSize: 5) >= 1
            case "solveEightByEight": shouldUnlock = stats.gamesPlayedCount(forSize: 8) >= 1
            case "under20Moves3x3":   shouldUnlock = stats.personalBestMoves[StatsKey(gridSize: 3, gameMode: .classic)].map { $0 <= 20 } ?? false
            case "under60Moves4x4":   shouldUnlock = stats.personalBestMoves[StatsKey(gridSize: 4, gameMode: .classic)].map { $0 <= 60 } ?? false
            case "streak10":          shouldUnlock = (stats.allTimeHighStreak.values.max() ?? 0) >= 10
            case "streak25":          shouldUnlock = (stats.allTimeHighStreak.values.max() ?? 0) >= 25
            default:                  shouldUnlock = false
            }
            if shouldUnlock {
                achievements[i].isUnlocked = true
                UserDefaults.standard.set(true, forKey: Keys.achievement(id: achievements[i].id))
                if newlyUnlockedAchievement == nil {
                    newlyUnlockedAchievement = achievements[i]
                }
            }
        }
    }

    func dismissAchievementNotification() async {
        newlyUnlockedAchievement = nil
    }
}

private extension AchievementsStore {
    enum Keys {
        static func achievement(id: String) -> String { "puzzle.achievement.\(id)" }
    }

    func loadAchievements() {
        let definitions = AchievementService.loadCached() ?? AchievementService.loadBundle()
        achievements = definitions.map { achievement in
            var a = achievement
            a.isUnlocked = UserDefaults.standard.bool(forKey: Keys.achievement(id: achievement.id))
            return a
        }
    }
}
