//
//  DailyChallengeStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/6/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("DailyChallengeStore")
@MainActor
struct DailyChallengeStoreTests {
    /// A fixed date (July 6, 2026, mid-day) so results are reproducible run to run.
    private var referenceDate: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12))!
    }

    private func day(offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: referenceDate)!
    }

    // MARK: - Completion history

    @Test func recordingCompletionAddsDayToHistory() {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())

        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        #expect(store.isDayCompleted(referenceDate))
        #expect(store.completedDayKeys == [20260706])
    }

    @Test func replayingSameDayDoesNotDuplicateHistory() {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())

        store.recordCompletion(moves: 20, time: 60, date: referenceDate)
        store.recordCompletion(moves: 15, time: 45, date: referenceDate)

        #expect(store.completedDayKeys.count == 1)
    }

    @Test func historySurvivesRelaunch() {
        let defaults = InMemoryPersistenceStore()
        let store = DailyChallengeStore(defaults: defaults)
        store.recordCompletion(moves: 20, time: 60, date: day(offset: -1))
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        let relaunched = DailyChallengeStore(defaults: defaults)

        #expect(relaunched.completedDayKeys == store.completedDayKeys)
        #expect(relaunched.isDayCompleted(referenceDate))
        #expect(relaunched.isDayCompleted(day(offset: -1)))
    }

    @Test func firstCompletedDateIsEarliestDayInHistory() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 20, time: 60, date: day(offset: -10))
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        let first = try #require(store.firstCompletedDate)

        #expect(Calendar.current.isDate(first, inSameDayAs: day(offset: -10)))
    }

    @Test func uncompletedDayIsNotInHistory() {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        #expect(!store.isDayCompleted(day(offset: -1)))
    }

    // MARK: - Per-day records

    @Test func recordCompletionStoresDayRecordWithStreak() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 20, time: 60, date: day(offset: -1))

        store.recordCompletion(moves: 25, time: 80, date: referenceDate)

        let record = try #require(store.record(for: referenceDate))
        #expect(record.moves == 25)
        #expect(record.time == 80)
        #expect(record.streak == 2)
    }

    @Test func replayingSameDayKeepsFirstCompletionRecord() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 30, time: 90, date: referenceDate)

        store.recordCompletion(moves: 10, time: 20, date: referenceDate)

        let record = try #require(store.record(for: referenceDate))
        #expect(record.moves == 30)
        #expect(record.time == 90)
    }

    @Test func dayRecordsSurviveRelaunch() throws {
        let defaults = InMemoryPersistenceStore()
        let store = DailyChallengeStore(defaults: defaults)
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        let relaunched = DailyChallengeStore(defaults: defaults)

        let record = try #require(relaunched.record(for: referenceDate))
        #expect(record == store.record(for: referenceDate))
    }

    @Test func dayWithoutRecordReturnsNil() {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        #expect(store.record(for: day(offset: -1)) == nil)
    }

    @Test func resetStatsClearsDayRecords() {
        let defaults = InMemoryPersistenceStore()
        let store = DailyChallengeStore(defaults: defaults)
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        store.resetStats()

        #expect(store.record(for: referenceDate) == nil)
        #expect(DailyChallengeStore(defaults: defaults).record(for: referenceDate) == nil)
    }

    // MARK: - Past-day replays

    @Test func pastReplayDoesNotAdvanceCalendarStreak() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        let result = store.recordCompletion(moves: 15, time: 45, date: day(offset: -3), isPastReplay: true)

        #expect(store.calendarStreak == 1)
        #expect(!result.isNewCalendarStreakRecord)
        let last = try #require(store.lastCompletedDate)
        #expect(Calendar.current.isDate(last, inSameDayAs: referenceDate))
    }

    @Test func pastReplayAddsDayToHistoryAndBackfillsRecord() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())

        store.recordCompletion(moves: 18, time: 50, date: day(offset: -5), isPastReplay: true)

        #expect(store.isDayCompleted(day(offset: -5)))
        let record = try #require(store.record(for: day(offset: -5)))
        #expect(record.moves == 18)
        #expect(record.time == 50)
        #expect(record.streak == 1)
    }

    @Test func backfilledRecordStreakCountsCompletedRunEndingThatDay() throws {
        // A pre-records player: three consecutive completed days in history, no stats.
        let defaults = InMemoryPersistenceStore()
        let keys = [-3, -2, -1].map { DailyChallengeStore.dayKey(for: day(offset: $0)) }
        defaults.set(keys, forKey: "daily.completedDays")
        let store = DailyChallengeStore(defaults: defaults)

        store.recordCompletion(moves: 22, time: 70, date: day(offset: -1), isPastReplay: true)

        let record = try #require(store.record(for: day(offset: -1)))
        #expect(record.streak == 3)
    }

    @Test func pastReplayKeepsExistingDayRecord() throws {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 30, time: 90, date: day(offset: -1))

        store.recordCompletion(moves: 10, time: 20, date: day(offset: -1), isPastReplay: true)

        let record = try #require(store.record(for: day(offset: -1)))
        #expect(record.moves == 30)
        #expect(record.time == 90)
    }

    @Test func pastReplayCanStillImproveAllTimeBests() {
        let store = DailyChallengeStore(defaults: InMemoryPersistenceStore())
        store.recordCompletion(moves: 30, time: 90, date: referenceDate)

        let result = store.recordCompletion(moves: 10, time: 20, date: day(offset: -2), isPastReplay: true)

        #expect(result.isNewMovesRecord)
        #expect(result.isNewTimeRecord)
        #expect(store.bestMoves == 10)
        #expect(store.bestTime == 20)
    }

    // MARK: - Migration from pre-history data

    @Test func migrationBackfillsCurrentStreakDays() {
        // A player from before history existed: streak of 3 ending yesterday,
        // but no stored completed-days array.
        let defaults = InMemoryPersistenceStore()
        defaults.set(3, forKey: "daily.calendarStreak")
        defaults.set(day(offset: -1).timeIntervalSinceReferenceDate, forKey: "daily.lastCompletedDate")

        let store = DailyChallengeStore(defaults: defaults)

        #expect(store.completedDayKeys.count == 3)
        #expect(store.isDayCompleted(day(offset: -1)))
        #expect(store.isDayCompleted(day(offset: -2)))
        #expect(store.isDayCompleted(day(offset: -3)))
        #expect(!store.isDayCompleted(referenceDate))
    }

    @Test func migrationRunsOnlyWhenNoHistoryIsStored() {
        // An existing (even empty) history array must win over backfilling.
        let defaults = InMemoryPersistenceStore()
        defaults.set(5, forKey: "daily.calendarStreak")
        defaults.set(day(offset: -1).timeIntervalSinceReferenceDate, forKey: "daily.lastCompletedDate")
        defaults.set([Int](), forKey: "daily.completedDays")

        let store = DailyChallengeStore(defaults: defaults)

        #expect(store.completedDayKeys.isEmpty)
    }

    // MARK: - Reset

    @Test func resetStatsClearsHistory() {
        let defaults = InMemoryPersistenceStore()
        let store = DailyChallengeStore(defaults: defaults)
        store.recordCompletion(moves: 20, time: 60, date: referenceDate)

        store.resetStats()

        #expect(store.completedDayKeys.isEmpty)
        // A relaunch must not resurrect the history via the streak migration.
        #expect(DailyChallengeStore(defaults: defaults).completedDayKeys.isEmpty)
    }

    // MARK: - Day-key round trip

    @Test func dayKeyRoundTripsThroughDate() throws {
        let key = DailyChallengeStore.dayKey(for: referenceDate)

        #expect(key == 20260706)
        let restored = try #require(DailyChallengeStore.date(fromDayKey: key))
        #expect(Calendar.current.isDate(restored, inSameDayAs: referenceDate))
    }
}
