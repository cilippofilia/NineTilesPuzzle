//
//  AchievementsStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation
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

    private func achievement(
        _ id: String,
        metric: AchievementMetric = .totalGamesPlayed,
        target: Int = 0,
        comparison: AchievementComparison = .greaterThanOrEqual
    ) -> Achievement {
        Achievement(id: id, title: id, description: id, systemImage: "star", metric: metric, target: target, comparison: comparison)
    }

    @Test func unlocksOnceTheMetricReachesItsTarget() {
        let store = makeStore(achievements: [achievement("firstSolve", metric: .totalGamesPlayed, target: 1)])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
        #expect(store.newlyUnlockedAchievement?.id == "firstSolve")
        #expect(store.achievements[0].unlockedDate != nil)
    }

    @Test func doesNotUnlockBeforeThresholdIsReached() {
        let store = makeStore(achievements: [achievement("tenGames", metric: .totalGamesPlayed, target: 10)])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])

        store.checkAchievements(using: stats)

        #expect(!store.achievements[0].isUnlocked)
        #expect(store.newlyUnlockedAchievement == nil)
    }

    @Test func gamesPlayedForSizeDependsOnSizeNotTotalGames() {
        let store = makeStore(achievements: [achievement("solveFourByFour", metric: .gamesPlayedForSize(4), target: 1)])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 5])

        store.checkAchievements(using: stats)
        #expect(!store.achievements[0].isUnlocked)

        let statsWithFour = makeStats(gamesPlayed: [StatsKey(gridSize: 4, gameMode: .slide): 1])
        store.checkAchievements(using: statsWithFour)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func lessThanOrEqualComparisonRequiresMovesAtOrUnderTarget() {
        let store = makeStore(achievements: [
            achievement("under20Moves3x3", metric: .personalBestMoves(size: 3, mode: .swap), target: 20, comparison: .lessThanOrEqual)
        ])
        let tooSlow = makeStats(personalBestMoves: [StatsKey(gridSize: 3, gameMode: .swap): 25])
        store.checkAchievements(using: tooSlow)
        #expect(!store.achievements[0].isUnlocked)

        let fastEnough = makeStats(personalBestMoves: [StatsKey(gridSize: 3, gameMode: .swap): 20])
        store.checkAchievements(using: fastEnough)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func streakAchievementsLookAtTheMaxAcrossAllKeys() {
        let store = makeStore(achievements: [achievement("streak10", metric: .bestStreakOverall, target: 10)])
        let stats = makeStats(allTimeHighStreak: [
            StatsKey(gridSize: 3, gameMode: .swap): 4,
            StatsKey(gridSize: 5, gameMode: .slide): 10
        ])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
    }

    @Test func alreadyUnlockedAchievementsAreNeverReEvaluated() {
        let store = makeStore(achievements: [achievement("firstSolve", metric: .totalGamesPlayed, target: 1)])
        store.achievements[0].isUnlocked = true
        let stats = makeStats()

        store.checkAchievements(using: stats)

        #expect(store.newlyUnlockedAchievement == nil)
    }

    @Test func onlyTheFirstNewUnlockInAPassBecomesTheNotification() {
        let store = makeStore(achievements: [
            achievement("firstSolve", metric: .totalGamesPlayed, target: 1),
            achievement("tenGames", metric: .totalGamesPlayed, target: 10)
        ])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 10])

        store.checkAchievements(using: stats)

        #expect(store.achievements.allSatisfy { $0.isUnlocked })
        #expect(store.newlyUnlockedAchievement?.id == "firstSolve")
    }

    @Test func dismissAchievementNotificationClearsIt() async {
        let store = makeStore(achievements: [achievement("firstSolve", metric: .totalGamesPlayed, target: 1)])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])
        store.checkAchievements(using: stats)
        #expect(store.newlyUnlockedAchievement != nil)

        await store.dismissAchievementNotification()

        #expect(store.newlyUnlockedAchievement == nil)
    }

    // MARK: - Time-of-day metrics

    @Test func nightOwlMetricOnlyCountsTheExactCallThatJustSolved() {
        let store = makeStore(achievements: [
            achievement("nightOwl", metric: .soloedInHourRange(start: 0, end: 5), target: 1)
        ])
        let stats = makeStats()
        let twoAM = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: .now)!

        store.checkAchievements(using: stats, justSolved: false, now: twoAM)
        #expect(!store.achievements[0].isUnlocked)

        store.checkAchievements(using: stats, justSolved: true, now: twoAM)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func nightOwlMetricDoesNotUnlockOutsideItsHourRange() {
        let store = makeStore(achievements: [
            achievement("nightOwl", metric: .soloedInHourRange(start: 0, end: 5), target: 1)
        ])
        let stats = makeStats()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!

        store.checkAchievements(using: stats, justSolved: true, now: noon)

        #expect(!store.achievements[0].isUnlocked)
    }

    // MARK: - Completionist

    @Test func completionistUnlocksOnceEveryOtherAchievementIsUnlocked() {
        let store = makeStore(achievements: [
            achievement("firstSolve", metric: .totalGamesPlayed, target: 1),
            achievement("completionist")
        ])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
        #expect(store.achievements[1].id == "completionist")
        #expect(store.achievements[1].isUnlocked)
    }

    @Test func completionistStaysLockedWhileAnyOtherAchievementIsLocked() {
        let store = makeStore(achievements: [
            achievement("firstSolve", metric: .totalGamesPlayed, target: 1),
            achievement("tenGames", metric: .totalGamesPlayed, target: 10),
            achievement("completionist")
        ])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])

        store.checkAchievements(using: stats)

        #expect(store.achievements[0].isUnlocked)
        #expect(!store.achievements[1].isUnlocked)
        #expect(!store.achievements.first(where: { $0.id == "completionist" })!.isUnlocked)
    }

    @Test func completionistIsRevokedWhenANewAchievementIsAddedAndNotYetEarned() {
        let store = makeStore(achievements: [achievement("firstSolve", metric: .totalGamesPlayed, target: 1)])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])
        store.achievements.append(achievement("completionist"))
        store.checkAchievements(using: stats)
        #expect(store.achievements.first(where: { $0.id == "completionist" })!.isUnlocked)

        // Simulates an app update introducing a new, not-yet-earned achievement.
        store.achievements.append(achievement("hundredGames", metric: .totalGamesPlayed, target: 100))
        store.checkAchievements(using: stats)

        #expect(!store.achievements.first(where: { $0.id == "completionist" })!.isUnlocked)
    }

    @Test func completionistNeverUnlocksWhenItIsTheOnlyAchievement() {
        let store = makeStore(achievements: [achievement("completionist")])
        let stats = makeStats()

        store.checkAchievements(using: stats)

        #expect(!store.achievements[0].isUnlocked)
    }

    // MARK: - Challenge Friends gating

    @Test func challengeFriendsAchievementsDoNotUnlockWhileTheFeatureIsDisabled() {
        // Target 0 means the metric (0, absent a ChallengeStore) already satisfies the
        // comparison — this isolates the gate itself rather than the metric's own value.
        let store = makeStore(achievements: [achievement("firstChallengeSent", metric: .challengesSent, target: 0)])
        let stats = makeStats()

        store.checkAchievements(using: stats, challengeFriendsEnabled: false)
        #expect(!store.achievements[0].isUnlocked)

        store.checkAchievements(using: stats, challengeFriendsEnabled: true)
        #expect(store.achievements[0].isUnlocked)
    }

    @Test func challengeFriendsAchievementsAreHiddenFromVisibleAchievementsWhileDisabled() {
        let store = makeStore(achievements: [
            achievement("firstSolve", metric: .totalGamesPlayed, target: 1),
            achievement("firstChallengeSent", metric: .challengesSent, target: 1)
        ])

        #expect(store.visibleAchievements(challengeFriendsEnabled: false).map(\.id) == ["firstSolve"])
        #expect(store.visibleAchievements(challengeFriendsEnabled: true).map(\.id) == ["firstSolve", "firstChallengeSent"])
        #expect(store.unlockedCount(challengeFriendsEnabled: false) == 0)
    }

    @Test func completionistIgnoresChallengeFriendsAchievementsWhileTheFeatureIsDisabled() {
        let store = makeStore(achievements: [
            achievement("firstSolve", metric: .totalGamesPlayed, target: 1),
            achievement("firstChallengeSent", metric: .challengesSent, target: 1),
            achievement("completionist")
        ])
        let stats = makeStats(gamesPlayed: [StatsKey(gridSize: 3, gameMode: .swap): 1])

        store.checkAchievements(using: stats, challengeFriendsEnabled: false)

        #expect(store.achievements[0].isUnlocked)
        #expect(!store.achievements[1].isUnlocked)
        #expect(store.achievements.first(where: { $0.id == "completionist" })!.isUnlocked)
    }
}
