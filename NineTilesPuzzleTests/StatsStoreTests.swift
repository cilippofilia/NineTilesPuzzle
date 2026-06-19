//
//  StatsStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/19/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("StatsStore")
@MainActor
struct StatsStoreTests {
    /// A fresh in-memory store per test so these never touch (or get polluted by) the
    /// app's real persisted stats.
    private func makeStore() -> StatsStore {
        StatsStore(defaults: InMemoryPersistenceStore())
    }

    private let classic3 = StatsKey(gridSize: 3, gameMode: .classic)
    private let classic4 = StatsKey(gridSize: 4, gameMode: .classic)
    private let slide3 = StatsKey(gridSize: 3, gameMode: .slide)

    // MARK: - recordCompletion

    @Test func firstCompletionSetsBothPersonalBests() {
        let store = makeStore()
        let result = store.recordCompletion(for: classic3, moves: 20, time: 30)
        #expect(result.isNewMovesRecord)
        #expect(result.isNewBestTime)
        #expect(store.personalBestMoves[classic3] == 20)
        #expect(store.personalBestTime[classic3] == 30)
        #expect(store.gamesPlayed[classic3] == 1)
    }

    @Test func worseCompletionDoesNotOverwriteBestsButStillCountsGame() {
        let store = makeStore()
        store.recordCompletion(for: classic3, moves: 20, time: 30)
        let result = store.recordCompletion(for: classic3, moves: 25, time: 40)
        #expect(!result.isNewMovesRecord)
        #expect(!result.isNewBestTime)
        #expect(store.personalBestMoves[classic3] == 20)
        #expect(store.personalBestTime[classic3] == 30)
        #expect(store.gamesPlayed[classic3] == 2)
    }

    @Test func mixedCompletionUpdatesOnlyTheImprovedRecord() {
        let store = makeStore()
        store.recordCompletion(for: classic3, moves: 20, time: 30)
        let result = store.recordCompletion(for: classic3, moves: 15, time: 45)
        #expect(result.isNewMovesRecord)
        #expect(!result.isNewBestTime)
        #expect(store.personalBestMoves[classic3] == 15)
        #expect(store.personalBestTime[classic3] == 30)
    }

    @Test func recordGamePlayedNeverTouchesPersonalBests() {
        let store = makeStore()
        store.recordGamePlayed(for: classic3)
        store.recordGamePlayed(for: classic3)
        #expect(store.gamesPlayed[classic3] == 2)
        #expect(store.personalBestMoves[classic3] == nil)
        #expect(store.personalBestTime[classic3] == nil)
    }

    @Test func gamesPlayedCountSumsAcrossModesForASize() {
        let store = makeStore()
        store.recordGamePlayed(for: classic3)
        store.recordGamePlayed(for: slide3)
        store.recordGamePlayed(for: classic4)
        #expect(store.gamesPlayedCount(forSize: 3) == 2)
        #expect(store.gamesPlayedCount(forSize: 4) == 1)
    }

    // MARK: - recordStreakIncrement

    @Test func streakIncrementsAndSetsAllTimeHighOnFirstMove() {
        let store = makeStore()
        let result = store.recordStreakIncrement(for: classic3, trackRecord: true)
        #expect(result.streak == 1)
        #expect(result.isNewRecord)
        #expect(store.currentStreak[classic3] == 1)
        #expect(store.allTimeHighStreak[classic3] == 1)
    }

    @Test func streakBelowAllTimeHighIsNotANewRecord() {
        let store = makeStore()
        store.recordStreakIncrement(for: classic3, trackRecord: true)
        store.recordStreakIncrement(for: classic3, trackRecord: true)
        store.resetStreak(for: classic3)
        let result = store.recordStreakIncrement(for: classic3, trackRecord: true)
        #expect(result.streak == 1)
        #expect(!result.isNewRecord)
        #expect(store.allTimeHighStreak[classic3] == 2)
    }

    @Test func untrackedStreakStillAdvancesButNeverUpdatesAllTimeHigh() {
        let store = makeStore()
        let result = store.recordStreakIncrement(for: classic3, trackRecord: false)
        #expect(result.streak == 1)
        #expect(!result.isNewRecord)
        #expect(store.currentStreak[classic3] == 1)
        #expect(store.allTimeHighStreak[classic3] == nil)
    }

    @Test func resetStreakZeroesOnlyTheGivenKey() {
        let store = makeStore()
        store.recordStreakIncrement(for: classic3, trackRecord: true)
        store.recordStreakIncrement(for: slide3, trackRecord: true)
        store.resetStreak(for: classic3)
        #expect(store.currentStreak[classic3] == 0)
        #expect(store.currentStreak[slide3] == 1)
    }

    // MARK: - StatsKey isolation

    /// Regression coverage for the bug where streaks and personal bests were shared across
    /// every grid size and game mode instead of being scoped per `StatsKey`.
    @Test func statsAtDifferentKeysNeverBleedIntoEachOther() {
        let store = makeStore()
        store.recordCompletion(for: classic3, moves: 10, time: 20)
        store.recordStreakIncrement(for: classic3, trackRecord: true)

        #expect(store.personalBestMoves[classic4] == nil)
        #expect(store.personalBestMoves[slide3] == nil)
        #expect(store.currentStreak[classic4] == nil)
        #expect(store.currentStreak[slide3] == nil)
        #expect(store.gamesPlayedCount(forSize: 4) == 0)
    }

    // MARK: - resetStats

    @Test func resetStatsClearsEverything() {
        let store = makeStore()
        store.recordCompletion(for: classic3, moves: 10, time: 20)
        store.recordStreakIncrement(for: slide3, trackRecord: true)

        store.resetStats()

        #expect(store.personalBestMoves.isEmpty)
        #expect(store.personalBestTime.isEmpty)
        #expect(store.gamesPlayed.isEmpty)
        #expect(store.currentStreak.isEmpty)
        #expect(store.allTimeHighStreak.isEmpty)
    }

    // MARK: - persistence round-trip

    @Test func restoresPersistedStatsOnInit() {
        let defaults = InMemoryPersistenceStore()

        let first = StatsStore(defaults: defaults)
        first.recordCompletion(for: classic3, moves: 12, time: 18)
        first.recordStreakIncrement(for: classic3, trackRecord: true)

        let second = StatsStore(defaults: defaults)
        #expect(second.personalBestMoves[classic3] == 12)
        #expect(second.personalBestTime[classic3] == 18)
        #expect(second.gamesPlayed[classic3] == 1)
        #expect(second.currentStreak[classic3] == 1)
        #expect(second.allTimeHighStreak[classic3] == 1)
    }
}
