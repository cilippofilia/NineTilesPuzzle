//
//  DailyMonthGridView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// One month section of the daily-challenge history calendar: a "June 2026"
/// header above a 7-column grid of day cells, aligned to the weekday of day 1.
/// Completed days are tappable and report via `onDayTap`.
struct DailyMonthGridView: View {
    @Environment(DailyChallengeStore.self) private var dailyStore
    let month: DailyCalendarMonth
    let today: Date
    let onDayTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(alignment: .leading) {
            Text(month.monthStart, format: .dateTime.month(.wide).year())
                .font(.title3)
                .bold()

            Divider()

            LazyVGrid(columns: columns) {
                ForEach(0..<month.leadingBlankCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
                ForEach(month.days, id: \.self) { day in
                    if state(for: day) == .completed {
                        Button {
                            onDayTap(day)
                        } label: {
                            DailyDayCellView(date: day, state: .completed, streakCount: streakBadge(for: day))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows that day's challenge card")
                    } else {
                        DailyDayCellView(date: day, state: state(for: day), streakCount: streakBadge(for: day))
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 20))
    }

    /// The ongoing streak count when `day` is the streak's last completed day, else `nil`.
    private func streakBadge(for day: Date) -> Int? {
        guard let badge = dailyStore.ongoingStreakBadge,
              Calendar.current.isDate(day, inSameDayAs: badge.date) else { return nil }
        return badge.count
    }

    private func state(for day: Date) -> DailyDayState {
        if dailyStore.isDayCompleted(day) {
            return .completed
        }
        let calendar = Calendar.current
        if calendar.startOfDay(for: day) > calendar.startOfDay(for: today) {
            return .upcoming
        }
        return .missed
    }
}

#Preview {
    DailyMonthGridView(month: .month(containing: .now), today: .now, onDayTap: { _ in })
        .environment(DailyChallengeStore())
        .padding()
}
