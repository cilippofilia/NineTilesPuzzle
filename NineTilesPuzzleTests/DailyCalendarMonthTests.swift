//
//  DailyCalendarMonthTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/6/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("DailyCalendarMonth")
struct DailyCalendarMonthTests {
    /// Gregorian calendar with Sunday as the first weekday, so leading-blank
    /// expectations don't depend on the test machine's locale.
    private var sundayFirstCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        return cal
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        sundayFirstCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func monthContainsEveryDayOfThatMonth() {
        let midJune = date(year: 2026, month: 6, day: 15)
        let june = DailyCalendarMonth.month(containing: midJune, calendar: sundayFirstCalendar)

        #expect(june.days.count == 30)
        #expect(sundayFirstCalendar.component(.day, from: june.days.first!) == 1)
        #expect(sundayFirstCalendar.component(.day, from: june.days.last!) == 30)
    }

    @Test func leadingBlanksAlignFirstDayWithItsWeekdayColumn() {
        let midJune = date(year: 2026, month: 6, day: 15)

        // June 1, 2026 is a Monday: one blank (Sunday) before it in a Sunday-first week.
        let june = DailyCalendarMonth.month(containing: midJune, calendar: sundayFirstCalendar)
        #expect(june.leadingBlankCount == 1)

        // With Monday as the first weekday there is no blank at all.
        var mondayFirst = sundayFirstCalendar
        mondayFirst.firstWeekday = 2
        let juneMondayFirst = DailyCalendarMonth.month(containing: midJune, calendar: mondayFirst)
        #expect(juneMondayFirst.leadingBlankCount == 0)
    }

    @Test func monthsSpanFromFirstThroughLastInclusive() {
        let months = DailyCalendarMonth.months(
            from: date(year: 2026, month: 5, day: 20),
            through: date(year: 2026, month: 7, day: 6),
            calendar: sundayFirstCalendar
        )

        #expect(months.count == 3)
        #expect(sundayFirstCalendar.component(.month, from: months[0].monthStart) == 5)
        #expect(sundayFirstCalendar.component(.month, from: months[2].monthStart) == 7)
    }

    @Test func monthsWithSameDayProducesSingleMonth() {
        let today = date(year: 2026, month: 7, day: 6)
        let months = DailyCalendarMonth.months(from: today, through: today, calendar: sundayFirstCalendar)

        #expect(months.count == 1)
    }

    @Test func monthsSwapsOutOfOrderDates() {
        let months = DailyCalendarMonth.months(
            from: date(year: 2026, month: 7, day: 6),
            through: date(year: 2026, month: 6, day: 1),
            calendar: sundayFirstCalendar
        )

        #expect(months.count == 2)
    }
}
