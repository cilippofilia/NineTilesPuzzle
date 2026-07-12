//
//  DailyChallengeProvider.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct DailyChallengeEntry: TimelineEntry {
    let date: Date
    let isCompletedToday: Bool
    let streak: Int
    let bestStreak: Int
    let gridSize: Int
    let mode: GameMode
    let imageData: Data?
}

struct DailyChallengeProvider: AppIntentTimelineProvider {
    /// Small enough that the seeded photo fetch is fast and cheap — it's only ever shown
    /// masked into the puzzle-piece watermark, never full-size.
    private static let imageSize = 200

    func placeholder(in context: Context) -> DailyChallengeEntry {
        DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide, imageData: nil)
    }

    func snapshot(for configuration: DailyChallengeConfigurationIntent, in context: Context) async -> DailyChallengeEntry {
        guard !context.isPreview else { return placeholder(in: context) }
        let imageData = configuration.showsPuzzlePhoto ? await Self.fetchImageData(for: .now) : nil
        return entry(for: .now, imageData: imageData)
    }

    func timeline(for configuration: DailyChallengeConfigurationIntent, in context: Context) async -> Timeline<DailyChallengeEntry> {
        let now = Date.now
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            let imageData = configuration.showsPuzzlePhoto ? await Self.fetchImageData(for: now) : nil
            return Timeline(entries: [entry(for: now, imageData: imageData)], policy: .atEnd)
        }

        // Two distinct calendar days can appear in one timeline (today's entries, plus the
        // midnight entry that's already "tomorrow"), so both seeded photos are fetched up front
        // — only when the user opted into the photo. The system URL cache means this is free on
        // every reload after the first.
        var todayImageData: Data?
        var tomorrowImageData: Data?
        if configuration.showsPuzzlePhoto {
            async let todayImage = Self.fetchImageData(for: now)
            async let tomorrowImage = Self.fetchImageData(for: dayEnd)
            (todayImageData, tomorrowImageData) = await (todayImage, tomorrowImage)
        }

        // One entry for now, one for each remaining 20%-of-the-day mark (so the date badge's
        // battery-style charge steps down on schedule), and one queued for midnight — so "done
        // today" flips off and the new day's grid/mode appear with no app involvement. The day's
        // identity comes from the seeder below; entry(for:) derives the charge from the date itself.
        var entries = [entry(for: now, imageData: todayImageData)]
        let dayLength = dayEnd.timeIntervalSince(dayStart)
        let chargeBoundaries = [0.2, 0.4, 0.6, 0.8].map { dayStart.addingTimeInterval(dayLength * $0) }
        for boundary in chargeBoundaries where boundary > now {
            entries.append(entry(for: boundary, imageData: todayImageData))
        }
        entries.append(entry(for: dayEnd, imageData: tomorrowImageData))
        return Timeline(entries: entries, policy: .after(dayEnd))
    }

    /// Builds the entry for `date` from the shared snapshot plus the seeder's deterministic
    /// day identity — which is what lets the midnight entry be computed ahead of time.
    private func entry(for date: Date, imageData: Data?) -> DailyChallengeEntry {
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
            mode: DailyChallengeSeeder.gameMode(for: date),
            imageData: imageData
        )
    }

    /// Downloads the seeded daily photo — same Picsum URL formula the main app uses for the
    /// puzzle itself, so the widget shows the same picture without any app-side coordination.
    private static func fetchImageData(for date: Date) async -> Data? {
        let url = DailyChallengeSeeder.imageURL(for: date, size: imageSize)
        return try? await URLSession.shared.data(from: url).0
    }
}
