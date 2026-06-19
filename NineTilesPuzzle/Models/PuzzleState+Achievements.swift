//
//  PuzzleState+Achievements.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

extension PuzzleState {
    func loadAchievements() {
        let definitions = AchievementService.loadCached() ?? AchievementService.loadBundle()
        achievements = definitions.map { achievement in
            var a = achievement
            a.isUnlocked = UserDefaults.standard.bool(forKey: Keys.achievement(id: achievement.id))
            return a
        }
    }

    func refreshAchievementsFromRemote() async {
        guard let definitions = try? await AchievementService.fetchRemote() else { return }
        achievements = definitions.map { achievement in
            var a = achievement
            a.isUnlocked = UserDefaults.standard.bool(forKey: Keys.achievement(id: achievement.id))
            return a
        }
        checkAchievements()
    }

    func checkAchievements() {
        let totalGames = gamesPlayed.values.reduce(0, +)
        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            let shouldUnlock: Bool
            switch achievements[i].id {
            case "firstSolve":        shouldUnlock = totalGames >= 1
            case "tenGames":          shouldUnlock = totalGames >= 10
            case "fiftyGames":        shouldUnlock = totalGames >= 50
            case "solveFourByFour":   shouldUnlock = gamesPlayedCount(forSize: 4) >= 1
            case "solveFiveByFive":   shouldUnlock = gamesPlayedCount(forSize: 5) >= 1
            case "solveEightByEight": shouldUnlock = gamesPlayedCount(forSize: 8) >= 1
            case "under20Moves3x3":   shouldUnlock = personalBestMoves[StatsKey(gridSize: 3, gameMode: .classic)].map { $0 <= 20 } ?? false
            case "under60Moves4x4":   shouldUnlock = personalBestMoves[StatsKey(gridSize: 4, gameMode: .classic)].map { $0 <= 60 } ?? false
            case "streak10":          shouldUnlock = (allTimeHighStreak.values.max() ?? 0) >= 10
            case "streak25":          shouldUnlock = (allTimeHighStreak.values.max() ?? 0) >= 25
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
