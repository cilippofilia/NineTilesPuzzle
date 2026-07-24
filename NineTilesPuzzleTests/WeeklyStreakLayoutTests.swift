//
//  WeeklyStreakLayoutTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/24/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("WeeklyStreakLayout")
struct WeeklyStreakLayoutTests {
    /// Fixed timezone so "today"/"days ago" math never depends on the test machine's locale.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func alwaysLaysOutMondayThroughSunday() {
        // 2026-07-22 is a Wednesday.
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 0, isCompletedToday: false, calendar: calendar)

        #expect(layout.days.count == 7)
        #expect(calendar.component(.weekday, from: layout.days.first!.date) == 2) // Monday
        #expect(calendar.component(.weekday, from: layout.days.last!.date) == 1) // Sunday
        #expect(calendar.component(.day, from: layout.days.first!.date) == 20)
        #expect(calendar.component(.day, from: layout.days.last!.date) == 26)
    }

    @Test func referenceDateOnSundayResolvesBackToThatWeeksMonday() {
        // Sunday is the last day of an ISO-8601 week — the boundary case for resolving
        // `weekOfYear` back to the correct (earlier) Monday rather than the next one.
        let sunday = date(year: 2026, month: 7, day: 26)
        let layout = WeeklyStreakLayout(referenceDate: sunday, streak: 0, isCompletedToday: false, calendar: calendar)

        #expect(calendar.component(.day, from: layout.days.first!.date) == 20) // Monday
        #expect(calendar.component(.day, from: layout.days.last!.date) == 26) // Sunday itself
    }

    @Test func referenceDateOnMondayIsAlreadyTheWeekStart() {
        let monday = date(year: 2026, month: 7, day: 20)
        let layout = WeeklyStreakLayout(referenceDate: monday, streak: 0, isCompletedToday: false, calendar: calendar)

        #expect(calendar.component(.day, from: layout.days.first!.date) == 20)
        #expect(calendar.component(.day, from: layout.days.last!.date) == 26)
    }

    @Test func noStreakLeavesEveryDayUnfilled() {
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 0, isCompletedToday: false, calendar: calendar)

        #expect(layout.days.allSatisfy { !$0.isFilled })
        #expect(layout.runs.count == 1)
    }

    @Test func streakEndingTodayFillsATrailingRun() {
        // Wednesday, completed today, streak of 3 covers today, yesterday, and the day before:
        // Mon/Tue/Wed filled, Thu...Sun still ahead.
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 3, isCompletedToday: true, calendar: calendar)

        let filledDays = layout.days.filter(\.isFilled).map { calendar.component(.day, from: $0.date) }
        #expect(filledDays == [20, 21, 22]) // Mon, Tue, Wed

        let pendingDays = layout.days.filter { !$0.isFilled }.map { calendar.component(.day, from: $0.date) }
        #expect(pendingDays == [23, 24, 25, 26]) // Thu...Sun, still ahead

        #expect(layout.runs.map(\.count) == [3, 4])
        #expect(layout.runs[0].allSatisfy { $0.isFilled })
        #expect(layout.runs[1].allSatisfy { !$0.isFilled })
    }

    @Test func shortStreakMidWeekLeavesEarlierDaysMissed() {
        // Wednesday, completed today, streak of 1 → only today is filled; Mon/Tue were missed,
        // Thu...Sun haven't happened yet. Three runs: missed, filled, ahead.
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 1, isCompletedToday: true, calendar: calendar)

        #expect(layout.runs.map(\.count) == [2, 1, 4])
        #expect(layout.runs[0].allSatisfy { !$0.isFilled })
        #expect(layout.runs[1].allSatisfy { $0.isFilled })
        #expect(layout.runs[2].allSatisfy { !$0.isFilled })
        #expect(calendar.component(.day, from: layout.runs[1][0].date) == 22) // Wednesday itself
    }

    @Test func todayNotYetCompletedExcludesTodayFromTheFilledRun() {
        // Wednesday, NOT completed today, streak of 2 → yesterday (Tue) and the day before
        // (Mon) are filled; today (Wed) and the rest of the week are pending.
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 2, isCompletedToday: false, calendar: calendar)

        let filledDays = layout.days.filter(\.isFilled).map { calendar.component(.day, from: $0.date) }
        #expect(filledDays == [20, 21]) // Mon, Tue

        let todayEntry = layout.days.first { calendar.component(.day, from: $0.date) == 22 }
        #expect(todayEntry?.isFilled == false)
    }

    @Test func longStreakFillsThroughTodayButNeverTheDaysAhead() {
        // However long the streak, it can't retroactively cover days that haven't happened
        // yet: Mon...Wed (through today) are filled, Thu...Sun still sit pending.
        let wednesday = date(year: 2026, month: 7, day: 22)
        let layout = WeeklyStreakLayout(referenceDate: wednesday, streak: 30, isCompletedToday: true, calendar: calendar)

        let filledDays = layout.days.filter(\.isFilled).map { calendar.component(.day, from: $0.date) }
        #expect(filledDays == [20, 21, 22]) // Mon, Tue, Wed

        #expect(layout.runs.map(\.count) == [3, 4])
        #expect(layout.runs[0].allSatisfy { $0.isFilled })
        #expect(layout.runs[1].allSatisfy { !$0.isFilled })
    }
}
