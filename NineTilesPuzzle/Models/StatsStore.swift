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
    var personalBestScore: [StatsKey: Int] = [:]
    var gamesPlayed: [StatsKey: Int] = [:]
    var currentStreak: [StatsKey: Int] = [:]
    var allTimeHighStreak: [StatsKey: Int] = [:]

    /// All-time best cumulative score / furthest stage reached across every Gauntlet
    /// Ladder run. Not scoped to a `StatsKey` — a ladder run spans every grid size in the
    /// stage table, so there's no single (gridSize, gameMode) pair to key it by.
    var bestLadderScore: Int = 0
    var bestLadderStageReached: Int = 0

    /// Lifetime flags/counters that back the data-driven achievement metrics in
    /// `AchievementMetric` — each is the simplest fact that can answer its achievement's
    /// question, not a full history.
    var hasZeroWasteSolve: Bool = false
    var hasSolvedWithPhotoLibrary: Bool = false
    var hasEverBrokenAStreak: Bool = false
    var hasComebackAfterBreak: Bool = false
    var maxGamesInOneDay: Int = 0
    private var gamesPlayedToday: Int = 0
    private var lastPlayedDay: Date?

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        restoreFromUserDefaults()
    }

    /// Total games played at `size`, summed across every game mode.
    func gamesPlayedCount(forSize size: Int) -> Int {
        gamesPlayed.filter { $0.key.gridSize == size }.values.reduce(0, +)
    }

    /// Distinct grid sizes completed at least once, across every mode — the "Full House" metric.
    var distinctGridSizesCleared: Int { Set(gamesPlayed.keys.map(\.gridSize)).count }

    /// Distinct game modes played at least once — the "Jack of All Trades" metric.
    var distinctGameModesPlayed: Int { Set(gamesPlayed.keys.map(\.gameMode)).count }

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

    /// Records a Time Trial score against `key`, updating the personal best if `score`
    /// beats it. Returns whether this was a new record.
    @discardableResult
    func recordTimeTrialScore(for key: StatsKey, score: Int) -> Bool {
        let existingScore = personalBestScore[key]
        guard existingScore == nil || score > existingScore! else { return false }

        personalBestScore[key] = score
        defaults.set(score, forKey: Keys.personalBestScore(for: key.gridSize, mode: key.gameMode))
        return true
    }

    /// Records a completed Gauntlet Ladder run's cumulative score, updating the all-time
    /// best if `score` beats it. Returns whether this was a new record.
    @discardableResult
    func recordLadderRunScore(_ score: Int) -> Bool {
        guard score > bestLadderScore else { return false }
        bestLadderScore = score
        defaults.set(score, forKey: Keys.bestLadderScore)
        return true
    }

    /// Records that `stage` was reached, updating the all-time best if it's further than
    /// any previous run got. Call with the stage just cleared, not the upcoming one.
    @discardableResult
    func recordLadderStageReached(_ stage: Int) -> Bool {
        guard stage > bestLadderStageReached else { return false }
        bestLadderStageReached = stage
        defaults.set(stage, forKey: Keys.bestLadderStageReached)
        return true
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

        if hasEverBrokenAStreak && !hasComebackAfterBreak && streak >= 10 {
            hasComebackAfterBreak = true
            defaults.set(true, forKey: Keys.hasComebackAfterBreak)
        }

        guard trackRecord, streak > (allTimeHighStreak[key] ?? 0) else { return (streak, false) }

        allTimeHighStreak[key] = streak
        defaults.set(streak, forKey: Keys.allTimeHighStreak(for: key.gridSize, mode: key.gameMode))
        return (streak, true)
    }

    /// Zeroes the streak at `key`. Also remembers, lifetime, that a streak was ever broken —
    /// the prerequisite for the "Comeback" achievement, checked in `recordStreakIncrement`.
    func resetStreak(for key: StatsKey) {
        if (currentStreak[key] ?? 0) > 0 {
            hasEverBrokenAStreak = true
            defaults.set(true, forKey: Keys.hasEverBrokenAStreak)
        }
        currentStreak[key] = 0
        defaults.set(0, forKey: Keys.currentStreak(for: key.gridSize, mode: key.gameMode))
    }

    /// Marks that a puzzle was solved without a single wasted move — every move locked a
    /// tile correctly. Lifetime, one-shot, like the other boolean achievement flags below.
    func recordZeroWasteSolve() {
        guard !hasZeroWasteSolve else { return }
        hasZeroWasteSolve = true
        defaults.set(true, forKey: Keys.hasZeroWasteSolve)
    }

    /// Marks that a puzzle was solved using a photo-library image.
    func recordPhotoLibrarySolve() {
        guard !hasSolvedWithPhotoLibrary else { return }
        hasSolvedWithPhotoLibrary = true
        defaults.set(true, forKey: Keys.hasSolvedWithPhotoLibrary)
    }

    /// Bumps today's completed-game tally and tracks the all-time daily high, for the
    /// "Marathon" achievement. Call once per completed game, any mode.
    func recordGameCompletedToday(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        if let lastPlayedDay, Calendar.current.isDate(lastPlayedDay, inSameDayAs: today) {
            gamesPlayedToday += 1
        } else {
            gamesPlayedToday = 1
            lastPlayedDay = today
            defaults.set(today.timeIntervalSinceReferenceDate, forKey: Keys.lastPlayedDay)
        }
        defaults.set(gamesPlayedToday, forKey: Keys.gamesPlayedToday)

        guard gamesPlayedToday > maxGamesInOneDay else { return }
        maxGamesInOneDay = gamesPlayedToday
        defaults.set(maxGamesInOneDay, forKey: Keys.maxGamesInOneDay)
    }

    func resetStats() {
        personalBestMoves = [:]
        personalBestTime = [:]
        personalBestScore = [:]
        gamesPlayed = [:]
        currentStreak = [:]
        allTimeHighStreak = [:]
        bestLadderScore = 0
        bestLadderStageReached = 0
        hasZeroWasteSolve = false
        hasSolvedWithPhotoLibrary = false
        hasEverBrokenAStreak = false
        hasComebackAfterBreak = false
        maxGamesInOneDay = 0
        gamesPlayedToday = 0
        lastPlayedDay = nil
        for mode in GameMode.allCases {
            for size in 3...8 {
                defaults.removeObject(forKey: Keys.personalBest(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.personalBestTime(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.personalBestScore(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.gamesPlayed(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.currentStreak(for: size, mode: mode))
                defaults.removeObject(forKey: Keys.allTimeHighStreak(for: size, mode: mode))
            }
        }
        defaults.removeObject(forKey: Keys.bestLadderScore)
        defaults.removeObject(forKey: Keys.bestLadderStageReached)
        defaults.removeObject(forKey: Keys.hasZeroWasteSolve)
        defaults.removeObject(forKey: Keys.hasSolvedWithPhotoLibrary)
        defaults.removeObject(forKey: Keys.hasEverBrokenAStreak)
        defaults.removeObject(forKey: Keys.hasComebackAfterBreak)
        defaults.removeObject(forKey: Keys.maxGamesInOneDay)
        defaults.removeObject(forKey: Keys.gamesPlayedToday)
        defaults.removeObject(forKey: Keys.lastPlayedDay)
    }
}

private extension StatsStore {
    enum Keys {
        static func personalBest(for size: Int, mode: GameMode) -> String { "puzzle.personalBest.\(mode.rawValue).\(size)" }
        static func personalBestTime(for size: Int, mode: GameMode) -> String { "puzzle.personalBestTime.\(mode.rawValue).\(size)" }
        static func personalBestScore(for size: Int, mode: GameMode) -> String { "puzzle.personalBestScore.\(mode.rawValue).\(size)" }
        static func gamesPlayed(for size: Int, mode: GameMode) -> String { "puzzle.gamesPlayed.\(mode.rawValue).\(size)" }
        static func currentStreak(for size: Int, mode: GameMode) -> String { "puzzle.currentStreak.\(mode.rawValue).\(size)" }
        static func allTimeHighStreak(for size: Int, mode: GameMode) -> String { "puzzle.allTimeHighStreak.\(mode.rawValue).\(size)" }
        static let bestLadderScore = "puzzle.bestLadderScore"
        static let bestLadderStageReached = "puzzle.bestLadderStageReached"
        static let hasZeroWasteSolve = "puzzle.hasZeroWasteSolve"
        static let hasSolvedWithPhotoLibrary = "puzzle.hasSolvedWithPhotoLibrary"
        static let hasEverBrokenAStreak = "puzzle.hasEverBrokenAStreak"
        static let hasComebackAfterBreak = "puzzle.hasComebackAfterBreak"
        static let maxGamesInOneDay = "puzzle.maxGamesInOneDay"
        static let gamesPlayedToday = "puzzle.gamesPlayedToday"
        static let lastPlayedDay = "puzzle.lastPlayedDay"
    }

    func restoreFromUserDefaults() {
        for mode in GameMode.allCases {
            for size in 3...8 {
                let key = StatsKey(gridSize: size, gameMode: mode)
                let moves = defaults.integer(forKey: Keys.personalBest(for: size, mode: mode))
                if moves > 0 { personalBestMoves[key] = moves }
                let time = defaults.double(forKey: Keys.personalBestTime(for: size, mode: mode))
                if time > 0 { personalBestTime[key] = time }
                let score = defaults.integer(forKey: Keys.personalBestScore(for: size, mode: mode))
                if score > 0 { personalBestScore[key] = score }
                let played = defaults.integer(forKey: Keys.gamesPlayed(for: size, mode: mode))
                if played > 0 { gamesPlayed[key] = played }
                let streak = defaults.integer(forKey: Keys.currentStreak(for: size, mode: mode))
                if streak > 0 { currentStreak[key] = streak }
                let bestStreak = defaults.integer(forKey: Keys.allTimeHighStreak(for: size, mode: mode))
                if bestStreak > 0 { allTimeHighStreak[key] = bestStreak }
            }
        }

        let ladderScore = defaults.integer(forKey: Keys.bestLadderScore)
        if ladderScore > 0 { bestLadderScore = ladderScore }
        let ladderStage = defaults.integer(forKey: Keys.bestLadderStageReached)
        if ladderStage > 0 { bestLadderStageReached = ladderStage }

        hasZeroWasteSolve = defaults.bool(forKey: Keys.hasZeroWasteSolve)
        hasSolvedWithPhotoLibrary = defaults.bool(forKey: Keys.hasSolvedWithPhotoLibrary)
        hasEverBrokenAStreak = defaults.bool(forKey: Keys.hasEverBrokenAStreak)
        hasComebackAfterBreak = defaults.bool(forKey: Keys.hasComebackAfterBreak)
        let dailyHigh = defaults.integer(forKey: Keys.maxGamesInOneDay)
        if dailyHigh > 0 { maxGamesInOneDay = dailyHigh }
        let playedToday = defaults.integer(forKey: Keys.gamesPlayedToday)
        if playedToday > 0 { gamesPlayedToday = playedToday }
        let lastPlayedDayValue = defaults.double(forKey: Keys.lastPlayedDay)
        if lastPlayedDayValue > 0 { lastPlayedDay = Date(timeIntervalSinceReferenceDate: lastPlayedDayValue) }
    }
}
