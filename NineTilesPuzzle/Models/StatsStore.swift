//
//  StatsStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

/// Historical records: personal bests, games played, and streaks, all keyed by grid size
/// and game mode. Owns nothing about the game currently in progress — `GameSession` reports
/// completed moves/games here and reads back whatever it needs to show "current" stats.
@MainActor
@Observable
final class StatsStore {
    private let defaults: PersistenceStore

    var personalBestMoves: [StatsKey: Int] = [:]
    var personalBestTime: [StatsKey: TimeInterval] = [:]
    var gamesPlayed: [StatsKey: Int] = [:]
    var currentStreak: [StatsKey: Int] = [:]
    var allTimeHighStreak: [StatsKey: Int] = [:]

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        restoreFromUserDefaults()
    }

    /// Total games played at `size`, summed across every game mode.
    func gamesPlayedCount(forSize size: Int) -> Int {
        gamesPlayed.filter { $0.key.gridSize == size }.values.reduce(0, +)
    }

    /// Records a completed game's move count and time against `key`, updating personal
    /// bests and the games-played tally. Returns which records (if any) were just broken.
    @discardableResult
    func recordCompletion(for key: StatsKey, moves: Int, time: TimeInterval) -> (isNewMovesRecord: Bool, isNewBestTime: Bool) {
        var isNewMovesRecord = false
        var isNewBestTime = false

        let existingMoves = personalBestMoves[key]
        if existingMoves == nil || moves < existingMoves! {
            personalBestMoves[key] = moves
            isNewMovesRecord = true
            defaults.set(moves, forKey: Keys.personalBest(for: key.gridSize, mode: key.gameMode))
        }

        let existingTime = personalBestTime[key]
        if existingTime == nil || time < existingTime! {
            personalBestTime[key] = time
            isNewBestTime = true
            defaults.set(time, forKey: Keys.personalBestTime(for: key.gridSize, mode: key.gameMode))
        }

        recordGamePlayed(for: key)
        return (isNewMovesRecord, isNewBestTime)
    }

    /// Bumps the games-played tally only — used by modes (e.g. Zen) that don't track
    /// personal bests but still count toward total-games achievements.
    func recordGamePlayed(for key: StatsKey) {
        gamesPlayed[key, default: 0] += 1
        defaults.set(gamesPlayed[key]!, forKey: Keys.gamesPlayed(for: key.gridSize, mode: key.gameMode))
    }

    /// Increments the streak at `key`. When `trackRecord` is false (e.g. practice/debug
    /// play), the streak still advances but never updates the all-time high.
    @discardableResult
    func recordStreakIncrement(for key: StatsKey, trackRecord: Bool) -> (streak: Int, isNewRecord: Bool) {
        let streak = currentStreak[key, default: 0] + 1
        currentStreak[key] = streak
        defaults.set(streak, forKey: Keys.currentStreak(for: key.gridSize, mode: key.gameMode))

        guard trackRecord, streak > (allTimeHighStreak[key] ?? 0) else { return (streak, false) }

        allTimeHighStreak[key] = streak
        defaults.set(streak, forKey: Keys.allTimeHighStreak(for: key.gridSize, mode: key.gameMode))
        return (streak, true)
    }

    func resetStreak(for key: StatsKey) {
        currentStreak[key] = 0
        defaults.set(0, forKey: Keys.currentStreak(for: key.gridSize, mode: key.gameMode))
    }

    func resetStats() {
        personalBestMoves = [:]
        personalBestTime = [:]
        gamesPlayed = [:]
        currentStreak = [:]
        allTimeHighStreak = [:]
        for mode in GameMode.allCases {
            for size in 3...8 {
                defaults.removeObject(forKey: Keys.personalBest(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.personalBestTime(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.gamesPlayed(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.currentStreak(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.allTimeHighStreak(for: size, mode: mode))
            }
        }
    }
}

private extension StatsStore {
    enum Keys {
        static func personalBest(for size: Int, mode: GameMode) -> String { "puzzle.personalBest.\(mode.rawValue).\(size)" }
        static func personalBestTime(for size: Int, mode: GameMode) -> String { "puzzle.personalBestTime.\(mode.rawValue).\(size)" }
        static func gamesPlayed(for size: Int, mode: GameMode) -> String { "puzzle.gamesPlayed.\(mode.rawValue).\(size)" }
        static func currentStreak(for size: Int, mode: GameMode) -> String { "puzzle.currentStreak.\(mode.rawValue).\(size)" }
        static func allTimeHighStreak(for size: Int, mode: GameMode) -> String { "puzzle.allTimeHighStreak.\(mode.rawValue).\(size)" }
    }

    func restoreFromUserDefaults() {
        for mode in GameMode.allCases {
            for size in 3...8 {
                let key = StatsKey(gridSize: size, gameMode: mode)
                let moves = defaults.integer(forKey: Keys.personalBest(for: size, mode: mode))
                if moves > 0 { personalBestMoves[key] = moves }
                let time = defaults.double(forKey: Keys.personalBestTime(for: size, mode: mode))
                if time > 0 { personalBestTime[key] = time }
                let played = defaults.integer(forKey: Keys.gamesPlayed(for: size, mode: mode))
                if played > 0 { gamesPlayed[key] = played }
                let streak = defaults.integer(forKey: Keys.currentStreak(for: size, mode: mode))
                if streak > 0 { currentStreak[key] = streak }
                let bestStreak = defaults.integer(forKey: Keys.allTimeHighStreak(for: size, mode: mode))
                if bestStreak > 0 { allTimeHighStreak[key] = bestStreak }
            }
        }
    }
}
