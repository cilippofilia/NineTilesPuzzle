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

    /// Every calendar day the player has ever completed, as `yyyymmdd` keys
    /// (same encoding as `DailyChallengeSeeder.seed`). Drives the history calendar.
    private(set) var completedDayKeys: Set<Int> = []

    /// Per-day stats keyed by `yyyymmdd`, captured on each day's first completion.
    /// Days completed before this existed appear in `completedDayKeys` only.
    private(set) var dayRecords: [Int: DailyDayRecord] = [:]

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

    /// The earliest day ever completed — anchors the first month of the history calendar.
    var firstCompletedDate: Date? {
        completedDayKeys.min().flatMap(Self.date(fromDayKey:))
    }

    /// The streak count to badge on the last completed day's calendar cell.
    /// Non-nil only while a streak of 2+ days is still alive — the last
    /// completion was today or yesterday relative to the effective date.
    var ongoingStreakBadge: (date: Date, count: Int)? {
        guard calendarStreak >= 2, let last = lastCompletedDate else { return nil }
        let cal = Calendar.current
        let daysAgo = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: last),
            to: cal.startOfDay(for: effectiveDate)
        ).day ?? .max
        guard daysAgo <= 1 else { return nil }
        return (last, calendarStreak)
    }

    /// True when the calendar day containing `date` has ever been completed.
    func isDayCompleted(_ date: Date) -> Bool {
        completedDayKeys.contains(Self.dayKey(for: date))
    }

    /// How many of the trailing 7 days (ending on and including `date`) have a completed
    /// Daily Challenge. Powers the weekly recap notification's "N of the last 7 days" figure.
    func completedDaysInTrailingWeek(endingOn date: Date = .now) -> Int {
        let cal = Calendar.current
        return (0..<7).reduce(into: 0) { count, dayOffset in
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: date) else { return }
            if completedDayKeys.contains(Self.dayKey(for: day)) { count += 1 }
        }
    }

    /// The stats captured on `date`'s first completion, or `nil` for days that
    /// were never completed or predate per-day record keeping.
    func record(for date: Date) -> DailyDayRecord? {
        dayRecords[Self.dayKey(for: date)]
    }

    /// Encodes the calendar day of `date` as a `yyyymmdd` integer, using
    /// `Calendar.current` so keys agree with the seeder's day boundaries.
    static func dayKey(for date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
    }

    /// Decodes a `yyyymmdd` key back into a `Date` (start of that day).
    static func date(fromDayKey key: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: key / 10_000, month: (key / 100) % 100, day: key % 100))
    }

    func setDebugDayOffset(_ offset: Int) {
        debugDayOffset = offset
    }

    func resetCompletionForDebug() {
        lastCompletedDate = nil
        defaults.removeObject(forKey: Keys.lastCompletedDate)
        // Drop the day from history too, so the calendar agrees with the daily card.
        completedDayKeys.remove(Self.dayKey(for: effectiveDate))
        persistCompletedDays()
        dayRecords.removeValue(forKey: Self.dayKey(for: effectiveDate))
        persistDayRecords()
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
    ///
    /// Pass `isPastReplay: true` when the completion comes from replaying an older
    /// day out of the history calendar: the day joins the completion history and,
    /// when it has no stored stats yet, gains a backfilled record — but the live
    /// calendar streak belongs to today's challenge and is never touched.
    @discardableResult
    func recordCompletion(moves: Int, time: TimeInterval, date: Date = .now, isPastReplay: Bool = false) -> (isNewMovesRecord: Bool, isNewTimeRecord: Bool, isNewCalendarStreakRecord: Bool) {
        var isNewCalendarStreakRecord = false
        if !isPastReplay && !isDailyCompletedToday {
            isNewCalendarStreakRecord = advanceCalendarStreak(for: date)
            lastCompletedDate = date
            defaults.set(date.timeIntervalSinceReferenceDate, forKey: Keys.lastCompletedDate)
        }

        let dayKey = Self.dayKey(for: date)
        if !completedDayKeys.contains(dayKey) {
            completedDayKeys.insert(dayKey)
            persistCompletedDays()
        }

        // First completion of the day wins — the stats that earned the streak
        // are the ones the history card shows; replays don't rewrite that run.
        if dayRecords[dayKey] == nil {
            // A backfilled past day never carried the live streak, so badge it with
            // the reconstructed run of completed days ending on that day instead.
            let streak = isPastReplay ? completedRunLength(endingOn: date) : calendarStreak
            dayRecords[dayKey] = DailyDayRecord(moves: moves, time: time, streak: streak)
            persistDayRecords()
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
        completedDayKeys = []
        dayRecords = [:]
        defaults.removeObject(forKey: Keys.calendarStreak)
        defaults.removeObject(forKey: Keys.bestCalendarStreak)
        defaults.removeObject(forKey: Keys.lastCompletedDate)
        defaults.removeObject(forKey: Keys.bestMoves)
        defaults.removeObject(forKey: Keys.bestTime)
        defaults.removeObject(forKey: Keys.completedDays)
        defaults.removeObject(forKey: Keys.dayRecords)
    }
}

private extension DailyChallengeStore {
    enum Keys {
        static let calendarStreak = "daily.calendarStreak"
        static let bestCalendarStreak = "daily.bestCalendarStreak"
        static let lastCompletedDate = "daily.lastCompletedDate"
        static let bestMoves = "daily.bestMoves"
        static let bestTime = "daily.bestTime"
        static let completedDays = "daily.completedDays"
        static let dayRecords = "daily.dayRecords"
    }

    func persistCompletedDays() {
        defaults.set(Array(completedDayKeys).sorted(), forKey: Keys.completedDays)
    }

    func persistDayRecords() {
        guard let data = try? JSONEncoder().encode(dayRecords) else { return }
        defaults.set(data, forKey: Keys.dayRecords)
    }

    /// The number of consecutive completed days ending on `date` (inclusive),
    /// reconstructed from the completion history. Used to badge backfilled records
    /// for days that were completed before per-day record keeping existed.
    func completedRunLength(endingOn date: Date) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: date)
        var count = 0
        while completedDayKeys.contains(Self.dayKey(for: day)) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
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

        if let data = defaults.data(forKey: Keys.dayRecords),
           let decoded = try? JSONDecoder().decode([Int: DailyDayRecord].self, from: data) {
            dayRecords = decoded
        }

        if let stored = defaults.object(forKey: Keys.completedDays) as? [Int] {
            completedDayKeys = Set(stored)
        } else if calendarStreak > 0, let last = lastCompletedDate {
            // One-time migration for players who completed dailies before history
            // existed: the only reconstructable days are the current streak's run,
            // counting back from the last completed day.
            let cal = Calendar.current
            for dayOffset in 0..<calendarStreak {
                if let day = cal.date(byAdding: .day, value: -dayOffset, to: last) {
                    completedDayKeys.insert(Self.dayKey(for: day))
                }
            }
            persistCompletedDays()
        }
    }
}
