//
//  DailyChallengeWidget.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

struct DailyChallengeEntry: TimelineEntry {
    let date: Date
    let isCompletedToday: Bool
    let streak: Int
    let bestStreak: Int
    let gridSize: Int
    let mode: GameMode
}

struct DailyChallengeProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyChallengeEntry {
        DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyChallengeEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyChallengeEntry>) -> Void) {
        let now = Date.now
        // One entry for now and one queued for midnight, so "done today" flips off and the
        // new day's grid/mode appear on schedule with no app involvement — the snapshot only
        // carries completion facts; the day's identity comes from the seeder below.
        var entries = [entry(for: now)]
        if let midnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(entry(for: midnight))
            completion(Timeline(entries: entries, policy: .after(midnight)))
        } else {
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    /// Builds the entry for `date` from the shared snapshot plus the seeder's deterministic
    /// day identity — which is what lets the midnight entry be computed ahead of time.
    private func entry(for date: Date) -> DailyChallengeEntry {
        let daily = WidgetDataStore.load()?.daily
        let calendar = Calendar.current

        var isCompleted = false
        var streak = 0
        if let daily, let lastCompletedDay = daily.lastCompletedDay {
            isCompleted = calendar.isDate(lastCompletedDay, inSameDayAs: date)
            // The streak is only alive if the last completion was today or yesterday —
            // mirroring `advanceCalendarStreak`, which resets to 1 after any missed day.
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))
            if isCompleted || yesterday.map({ calendar.isDate(lastCompletedDay, inSameDayAs: $0) }) == true {
                streak = daily.calendarStreak
            }
        }

        return DailyChallengeEntry(
            date: date,
            isCompletedToday: isCompleted,
            streak: streak,
            bestStreak: daily?.bestCalendarStreak ?? 0,
            gridSize: DailyChallengeSeeder.gridSize(for: date),
            mode: DailyChallengeSeeder.gameMode(for: date)
        )
    }
}

struct DailyChallengeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.dailyChallenge, provider: DailyChallengeProvider()) { entry in
            DailyChallengeWidgetView(entry: entry)
                .colorScheme(.dark)
        }
        .configurationDisplayName("Daily Challenge")
        .description("Today's puzzle at a glance — mode, grid size, and your calendar streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 4, mode: .slide)
}

#Preview("Medium", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 5, mode: .swap)
}
