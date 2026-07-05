//
//  StreaksRecordsWidget.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

struct StreaksRecordsEntry: TimelineEntry {
    let date: Date
    let mode: GameMode
    let gridSize: Int
    /// The chosen combination's stats, or `nil` when it has never been played.
    let stats: WidgetSnapshot.ModeStats?
}

struct StreaksRecordsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StreaksRecordsEntry {
        StreaksRecordsEntry(
            date: .now,
            mode: .slide,
            gridSize: 3,
            stats: WidgetSnapshot.ModeStats(
                gameModeRaw: GameMode.slide.rawValue,
                gridSize: 3,
                currentStreak: 4,
                allTimeHighStreak: 11,
                personalBestMoves: 26,
                personalBestTime: 74,
                gamesPlayed: 42
            )
        )
    }

    func snapshot(for configuration: StatsConfigurationIntent, in context: Context) async -> StreaksRecordsEntry {
        context.isPreview ? placeholder(in: context) : entry(for: configuration)
    }

    func timeline(
        for configuration: StatsConfigurationIntent,
        in context: Context
    ) async -> Timeline<StreaksRecordsEntry> {
        // Records only change through play, and the app reloads this kind explicitly at
        // game end/leave/reset — so a single entry that never expires is the whole timeline.
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: StatsConfigurationIntent) -> StreaksRecordsEntry {
        let mode = configuration.mode.gameMode
        let gridSize = configuration.gridSize.rawValue
        let stats = WidgetDataStore.load()?.modeStats.first {
            $0.gameModeRaw == mode.rawValue && $0.gridSize == gridSize
        }
        return StreaksRecordsEntry(date: .now, mode: mode, gridSize: gridSize, stats: stats)
    }
}

struct StreaksRecordsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.streaksRecords,
            intent: StatsConfigurationIntent.self,
            provider: StreaksRecordsProvider()
        ) { entry in
            // Keeps the card dark-only regardless of iOS's per-widget light/dark appearance
            // setting — see the matching note on DailyChallengeWidget.
            StreaksRecordsWidgetView(entry: entry)
                .colorScheme(.dark)
        }
        .configurationDisplayName("Streaks & Records")
        .description("Your current streak and personal bests for a chosen mode and grid size.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    StreaksRecordsWidget()
} timeline: {
    StreaksRecordsEntry(
        date: .now,
        mode: .slide,
        gridSize: 4,
        stats: WidgetSnapshot.ModeStats(
            gameModeRaw: GameMode.slide.rawValue,
            gridSize: 4,
            currentStreak: 7,
            allTimeHighStreak: 15,
            personalBestMoves: 41,
            personalBestTime: 128,
            gamesPlayed: 63
        )
    )
    StreaksRecordsEntry(date: .now, mode: .chaos, gridSize: 6, stats: nil)
}

#Preview("Medium", as: .systemMedium) {
    StreaksRecordsWidget()
} timeline: {
    StreaksRecordsEntry(
        date: .now,
        mode: .timeTrial,
        gridSize: 5,
        stats: WidgetSnapshot.ModeStats(
            gameModeRaw: GameMode.timeTrial.rawValue,
            gridSize: 5,
            currentStreak: 0,
            allTimeHighStreak: 0,
            personalBestScore: 1240,
            gamesPlayed: 18
        )
    )
    StreaksRecordsEntry(date: .now, mode: .fog, gridSize: 4, stats: nil)
}
