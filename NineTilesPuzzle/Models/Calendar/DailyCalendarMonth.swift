//
//  DailyCalendarMonth.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import Foundation

/// One month of the daily-challenge history calendar: the days to render and how
/// many leading blanks align day 1 with its weekday column. Pure date math, kept
/// out of the views so it can be unit-tested with a fixed calendar.
struct DailyCalendarMonth: Identifiable, Equatable {
    let monthStart: Date
    let days: [Date]
    let leadingBlankCount: Int

    var id: Date { monthStart }

    /// Builds the month containing `date`.
    static func month(containing date: Date, calendar: Calendar = .current) -> DailyCalendarMonth {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let days = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
        let weekday = calendar.component(.weekday, from: start)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        return DailyCalendarMonth(monthStart: start, days: days, leadingBlankCount: blanks)
    }

    /// Builds every month from the one containing `firstDate` through the one
    /// containing `lastDate`, in chronological order. Dates given out of order
    /// are swapped rather than producing an empty range.
    static func months(
        from firstDate: Date,
        through lastDate: Date,
        calendar: Calendar = .current
    ) -> [DailyCalendarMonth] {
        let earliest = min(firstDate, lastDate)
        let latest = max(firstDate, lastDate)
        guard
            let firstMonth = calendar.dateInterval(of: .month, for: earliest)?.start,
            let lastMonth = calendar.dateInterval(of: .month, for: latest)?.start
        else {
            return [month(containing: latest, calendar: calendar)]
        }

        var result: [DailyCalendarMonth] = []
        var current = firstMonth
        while current <= lastMonth {
            result.append(month(containing: current, calendar: calendar))
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}
