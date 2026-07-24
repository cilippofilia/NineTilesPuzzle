//
//  WeeklyStreakLayout.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/24/26.
//

import Foundation

/// The fixed Monday-through-Sunday calendar week for the Daily Challenge streak row, with each
/// day marked filled if it falls inside the streak still alive as of `referenceDate`. Unlike a
/// rolling "last 7 days" window, this always shows the current week — so a short streak leaves
/// earlier days in the week visibly missed, and days after today sit there unfilled as the week
/// ahead.
struct WeeklyStreakLayout {
    struct Day: Hashable {
        let date: Date
        let isFilled: Bool
    }

    /// Monday first, Sunday last — always 7 entries.
    let days: [Day]

    init(referenceDate: Date, streak: Int, isCompletedToday: Bool, calendar: Calendar = WeeklyStreakLayout.mondayFirstCalendar) {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start ?? startOfToday

        let filledDaysAgo: Set<Int> = {
            guard streak > 0 else { return [] }
            let start = isCompletedToday ? 0 : 1
            return Set(start..<(start + streak))
        }()

        days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let daysAgo = calendar.dateComponents([.day], from: day, to: startOfToday).day ?? 0
            return Day(date: day, isFilled: filledDaysAgo.contains(daysAgo))
        }
    }

    /// `days` split into contiguous filled/unfilled runs, in calendar order — a short streak
    /// starting mid-week yields three runs (missed days, the filled run, the days still ahead).
    var runs: [[Day]] {
        days.reduce(into: [[Day]]()) { runs, day in
            if runs.last?.first?.isFilled == day.isFilled {
                runs[runs.count - 1].append(day)
            } else {
                runs.append([day])
            }
        }
    }

    static let mondayFirstCalendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()
}
