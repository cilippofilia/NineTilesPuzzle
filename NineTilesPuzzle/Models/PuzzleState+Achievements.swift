//
//  PuzzleState+Achievements.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

extension PuzzleState {
    static let allAchievements: [Achievement] = [
        Achievement(
            id: "firstSolve",
            title: "First Solve",
            description: "Complete your first puzzle",
            systemImage: "puzzlepiece.fill"
        ),
        Achievement(
            id: "tenGames",
            title: "Dedicated",
            description: "Complete 10 puzzles",
            systemImage: "trophy.fill"
        ),
        Achievement(
            id: "fiftyGames",
            title: "On Fire",
            description: "Complete 50 puzzles",
            systemImage: "flame.fill"
        ),
        Achievement(
            id: "solveFourByFour",
            title: "Step Up",
            description: "Complete a 4×4 puzzle",
            systemImage: "square.grid.2x2.fill"
        ),
        Achievement(
            id: "solveFiveByFive",
            title: "Hard Mode",
            description: "Complete a 5×5 puzzle",
            systemImage: "square.grid.3x3.fill"
        ),
        Achievement(
            id: "solveEightByEight",
            title: "Insane",
            description: "Complete an 8×8 puzzle",
            systemImage: "infinity.circle.fill"
        ),
        Achievement(
            id: "under20Moves3x3",
            title: "Speed Demon",
            description: "Solve a 3×3 in 20 moves or fewer",
            systemImage: "bolt.fill"
        ),
        Achievement(
            id: "under60Moves4x4",
            title: "Efficient",
            description: "Solve a 4×4 in 60 moves or fewer",
            systemImage: "hare.fill"
        ),
        Achievement(
            id: "streak10",
            title: "On a Roll",
            description: "Reach a streak of 10",
            systemImage: "arrow.up.circle.fill"
        ),
        Achievement(
            id: "streak25",
            title: "Unstoppable",
            description: "Reach a streak of 25",
            systemImage: "crown.fill"
        )
    ]

    func loadAchievements() {
        let definitions = AchievementService.loadCached() ?? Self.allAchievements
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
            case "solveFourByFour":   shouldUnlock = (gamesPlayed[4] ?? 0) >= 1
            case "solveFiveByFive":   shouldUnlock = (gamesPlayed[5] ?? 0) >= 1
            case "solveEightByEight": shouldUnlock = (gamesPlayed[8] ?? 0) >= 1
            case "under20Moves3x3":   shouldUnlock = personalBestMoves[3].map { $0 <= 20 } ?? false
            case "under60Moves4x4":   shouldUnlock = personalBestMoves[4].map { $0 <= 60 } ?? false
            case "streak10":          shouldUnlock = allTimeHighStreak >= 10
            case "streak25":          shouldUnlock = allTimeHighStreak >= 25
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
