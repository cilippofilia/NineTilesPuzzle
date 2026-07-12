//
//  DailyChallengeProvider.swift
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
        let calendar = Calendar.current
        // One entry for now, one for each remaining 20%-of-the-day mark (so the date badge's
        // battery-style charge steps down on schedule), and one queued for midnight — so "done
        // today" flips off and the new day's grid/mode appear with no app involvement. The day's
        // identity comes from the seeder below; entry(for:) derives the charge from the date itself.
        var entries = [entry(for: now)]
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            completion(Timeline(entries: entries, policy: .atEnd))
            return
        }
        let dayLength = dayEnd.timeIntervalSince(dayStart)
        let chargeBoundaries = [0.2, 0.4, 0.6, 0.8].map { dayStart.addingTimeInterval(dayLength * $0) }
        for boundary in chargeBoundaries where boundary > now {
            entries.append(entry(for: boundary))
        }
        entries.append(entry(for: dayEnd))
        completion(Timeline(entries: entries, policy: .after(dayEnd)))
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
