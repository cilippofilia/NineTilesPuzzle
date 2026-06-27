//
//  DailyChallengeStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import Foundation

/// Tracks the player's daily-challenge history: calendar streak, all-time best
/// calendar streak, last completed date, and best moves/time. Fully independent
/// of `StatsStore` — daily records live here, not in the per-`StatsKey` tables.
@MainActor
@Observable
final class DailyChallengeStore {
    private let defaults: PersistenceStore

    private(set) var calendarStreak: Int = 0
    private(set) var bestCalendarStreak: Int = 0
    private(set) var lastCompletedDate: Date?
    private(set) var bestMoves: Int?
    private(set) var bestTime: TimeInterval?

    /// Debug-only day offset applied to every seeder and completion check.
    /// In-memory only — resets to 0 on each launch so it never affects production data.
    private(set) var debugDayOffset: Int = 0

    /// The date the daily challenge is running against. Equal to `.now` in production;
    /// offset by `debugDayOffset` days when the dev-tools offset is non-zero.
    var effectiveDate: Date {
        guard debugDayOffset != 0 else { return .now }
        return Calendar.current.date(byAdding: .day, value: debugDayOffset, to: .now) ?? .now
    }

    /// True when the effective date's daily challenge has already been completed at least once.
    var isDailyCompletedToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDate(last, inSameDayAs: effectiveDate)
    }

    func setDebugDayOffset(_ offset: Int) {
        debugDayOffset = offset
    }

    func resetCompletionForDebug() {
        lastCompletedDate = nil
        defaults.removeObject(forKey: Keys.lastCompletedDate)
    }

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        restoreFromUserDefaults()
    }

    /// Records a completed daily challenge.
    ///
    /// The calendar streak is advanced only the first time per calendar day —
    /// replaying the same puzzle (which is allowed) can still improve `bestMoves`
    /// and `bestTime` without double-counting the streak.
    @discardableResult
    func recordCompletion(moves: Int, time: TimeInterval, date: Date = .now) -> (isNewMovesRecord: Bool, isNewTimeRecord: Bool, isNewCalendarStreakRecord: Bool) {
        var isNewCalendarStreakRecord = false
        if !isDailyCompletedToday {
            isNewCalendarStreakRecord = advanceCalendarStreak(for: date)
            lastCompletedDate = date
            defaults.set(date.timeIntervalSinceReferenceDate, forKey: Keys.lastCompletedDate)
        }

        var isNewMovesRecord = false
        var isNewTimeRecord = false

        if bestMoves == nil || moves < bestMoves! {
            bestMoves = moves
            defaults.set(moves, forKey: Keys.bestMoves)
            isNewMovesRecord = true
        }
        if bestTime == nil || time < bestTime! {
            bestTime = time
            defaults.set(time, forKey: Keys.bestTime)
            isNewTimeRecord = true
        }

        return (isNewMovesRecord, isNewTimeRecord, isNewCalendarStreakRecord)
    }

    func resetStats() {
        calendarStreak = 0
        bestCalendarStreak = 0
        lastCompletedDate = nil
        bestMoves = nil
        bestTime = nil
        defaults.removeObject(forKey: Keys.calendarStreak)
        defaults.removeObject(forKey: Keys.bestCalendarStreak)
        defaults.removeObject(forKey: Keys.lastCompletedDate)
        defaults.removeObject(forKey: Keys.bestMoves)
        defaults.removeObject(forKey: Keys.bestTime)
    }
}

private extension DailyChallengeStore {
    enum Keys {
        static let calendarStreak = "daily.calendarStreak"
        static let bestCalendarStreak = "daily.bestCalendarStreak"
        static let lastCompletedDate = "daily.lastCompletedDate"
        static let bestMoves = "daily.bestMoves"
        static let bestTime = "daily.bestTime"
    }

    /// Increments the streak when today directly follows the last completed day;
    /// resets it to 1 when there's a gap (or no prior completion).
    /// Returns `true` when a new all-time best calendar streak is set.
    @discardableResult
    func advanceCalendarStreak(for date: Date) -> Bool {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))!
        if let last = lastCompletedDate, cal.isDate(last, inSameDayAs: yesterday) {
            calendarStreak += 1
        } else {
            calendarStreak = 1
        }
        defaults.set(calendarStreak, forKey: Keys.calendarStreak)
        guard calendarStreak > bestCalendarStreak else { return false }
        bestCalendarStreak = calendarStreak
        defaults.set(bestCalendarStreak, forKey: Keys.bestCalendarStreak)
        return true
    }

    func restoreFromUserDefaults() {
        let streak = defaults.integer(forKey: Keys.calendarStreak)
        if streak > 0 { calendarStreak = streak }
        let best = defaults.integer(forKey: Keys.bestCalendarStreak)
        if best > 0 { bestCalendarStreak = best }
        let lastDateInterval = defaults.double(forKey: Keys.lastCompletedDate)
        if lastDateInterval > 0 { lastCompletedDate = Date(timeIntervalSinceReferenceDate: lastDateInterval) }
        let moves = defaults.integer(forKey: Keys.bestMoves)
        if moves > 0 { bestMoves = moves }
        let time = defaults.double(forKey: Keys.bestTime)
        if time > 0 { bestTime = time }
    }
}
