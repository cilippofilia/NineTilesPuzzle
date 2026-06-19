//
//  AchievementsStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/19/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("AchievementsStore")
@MainActor
struct AchievementsStoreTests {
    /// A fresh in-memory store per test so unlocking real achievement ids (e.g.
    /// "firstSolve") in a test never writes to the app's real unlock flags.
    private func makeStore(achievements: [Achievement]) -> AchievementsStore {
        let store = AchievementsStore(defaults: InMemoryPersistenceStore())
        store.achievements = achievements
        return store
    }

    private func makeStats(
        gamesPlayed: [StatsKey: Int] = [:],
        personalBestMoves: [StatsKey: Int] = [:],
        allTimeHighStreak: [StatsKey: Int] = [:]
    ) -> StatsStore {
        let stats = StatsStore(defaults: InMemoryPersistenceStore())
        for (key, count) in gamesPlayed {
            for _ in 0..<count { stats.recordGamePlayed(for: key) }
        }
        for (key, moves) in personalBestMoves { stats.recordCompletion(for: key, moves: moves, time: 999) }
        for (key, streak) in allTimeHighStreak {
            for _ in 0..<streak { stats.recordStreakIncrement(for: key, trackRecord: true) }
        }
        return stats
    }

    private func achievement(_ id: String) -> Achievement {
        Achievement(id: id, title: id, description: id, systemImage: "star")
    }

    @Test func unlocksFirstSolveOnceAGameHasBeenPlayed() {
        let store = makeStore(achievements: [achievement("firstSolve")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 1])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
        #expect(store.newlyUnlockedAchievement?.id == "firstSolve")
    }

    @Test func doesNotUnlockBeforeThresholdIsReached() {
        let store = makeStore(achievements: [achievement("tenGames")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 1])

        store.checkAchievements(using: stats)

        #expect(!store.achievements[0].isUnlocked)
        #expect(store.newlyUnlockedAchievement == nil)
    }

    @Test func solveFourByFourDependsOnSizeNotTotalGames() {
        let store = makeStore(achievements: [achievement("solveFourByFour")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 5])

        store.checkAchievements(using: stats)
        #expect(!store.achievements[0].isUnlocked)

        let statsWithFour = makeStats(gamesPlayed: [StatsKey(gridSize: 4, gameMode: .slide): 1])
        store.checkAchievements(using: statsWithFour)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func under20Moves3x3RequiresClassicPersonalBest() {
        let store = makeStore(achievements: [achievement("under20Moves3x3")])
        let tooSlow = makeStats(personalBestMoves: [StatsKey(gridSize: 3, gameMode: .classic): 25])
        store.checkAchievements(using: tooSlow)
        #expect(!store.achievements[0].isUnlocked)

        let fastEnough = makeStats(personalBestMoves: [StatsKey(gridSize: 3, gameMode: .classic): 20])
        store.checkAchievements(using: fastEnough)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func streakAchievementsLookAtTheMaxAcrossAllKeys() {
        let store = makeStore(achievements: [achievement("streak10")])
        let stats = makeStats(allTimeHighStreak: [
            StatsKey(gridSize: 3, gameMode: .classic): 4,
            StatsKey(gridSize: 5, gameMode: .slide): 10
        ])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
    }

    @Test func alreadyUnlockedAchievementsAreNeverReEvaluated() {
        let store = makeStore(achievements: [achievement("firstSolve")])
        store.achievements[0].isUnlocked = true
        let stats = makeStats()

        store.checkAchievements(using: stats)

        #expect(store.newlyUnlockedAchievement == nil)
    }

    @Test func onlyTheFirstNewUnlockInAPassBecomesTheNotification() {
        let store = makeStore(achievements: [achievement("firstSolve"), achievement("tenGames")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 10])

        store.checkAchievements(using: stats)

        #expect(store.achievements.allSatisfy(\.isUnlocked))
        #expect(store.newlyUnlockedAchievement?.id == "firstSolve")
    }

    @Test func unknownIdNeverUnlocks() {
        let store = makeStore(achievements: [achievement("madeUpId")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 100])

        store.checkAchievements(using: stats)

        #expect(!store.achievements[0].isUnlocked)
    }

    @Test func dismissAchievementNotificationClearsIt() async {
        let store = makeStore(achievements: [achievement("firstSolve")])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .classic): 1])
        store.checkAchievements(using: stats)
        #expect(store.newlyUnlockedAchievement != nil)

        await store.dismissAchievementNotification()

        #expect(store.newlyUnlockedAchievement == nil)
    }
}
