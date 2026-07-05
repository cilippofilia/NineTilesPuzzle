//
//  StreaksRecordsViews.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

/// Family switch for the Streaks & Records widget. Tapping lands on the menu with the
/// configured mode and grid size preselected.
struct StreaksRecordsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreaksRecordsEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                StreaksRecordsMediumView(entry: entry)
            } else {
                StreaksRecordsSmallView(entry: entry)
            }
        }
        .widgetURL(DeepLink.mode(entry.mode, gridSize: entry.gridSize).url)
    }
}

/// Small card: mode identity up top, the streak flame front and center, best beneath.
struct StreaksRecordsSmallView: View {
    let entry: StreaksRecordsEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StreaksRecordsHeaderLabel(entry: entry)

            Spacer(minLength: 0)

            if let stats = entry.stats {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                    Text("\(stats.currentStreak)")
                        .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                }
                .widgetAccentable()

                Text("streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                StatBadge(icon: "trophy.fill", text: "Best \(stats.allTimeHighStreak)", accent: .yellow)
            } else {
                StreaksRecordsEmptyLabel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// Medium card: mode identity block on the left, a grid of stat pills on the right.
struct StreaksRecordsMediumView: View {
    let entry: StreaksRecordsEntry
    private let accent = Color.orange

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StreaksRecordsHeaderLabel(entry: entry)
                Image(systemName: entry.mode.icon)
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
                    )
                    .widgetAccentable()
                if let stats = entry.stats {
                    Text("\(stats.gamesPlayed) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let stats = entry.stats {
                StreaksRecordsStatsGrid(entry: entry, stats: stats, accent: accent)
            } else {
                StreaksRecordsEmptyLabel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// The 2×2 grid of stat pills. Time Trial swaps the moves/time records (it doesn't track
/// them) for its score record.
struct StreaksRecordsStatsGrid: View {
    let entry: StreaksRecordsEntry
    let stats: WidgetSnapshot.ModeStats
    let accent: Color

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                StatBadge(icon: "flame.fill", text: "\(stats.currentStreak)", accent: accent)
                StatBadge(icon: "trophy.fill", text: "\(stats.allTimeHighStreak)", accent: .yellow)
            }
            GridRow {
                if entry.mode == .timeTrial {
                    StatBadge(icon: "star.fill", text: score(stats.personalBestScore), accent: accent)
                        .gridCellColumns(2)
                } else {
                    StatBadge(icon: "figure.walk", text: moves(stats.personalBestMoves), accent: accent)
                    StatBadge(icon: "timer", text: time(stats.personalBestTime), accent: accent)
                }
            }
        }
        .widgetAccentable()
    }

    private func moves(_ value: Int?) -> String {
        value.map { "\($0)" } ?? "—"
    }

    private func time(_ value: TimeInterval?) -> String {
        value?.formattedMinutesSeconds ?? "—"
    }

    private func score(_ value: Int?) -> String {
        value.map { "\($0) pts" } ?? "— pts"
    }
}

/// The chosen combination's identity: mode icon + title, and the grid size.
struct StreaksRecordsHeaderLabel: View {
    let entry: StreaksRecordsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(entry.mode.title, systemImage: entry.mode.icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .widgetAccentable()
            Text("\(entry.gridSize) × \(entry.gridSize)")
                .font(.headline)
        }
    }
}

/// Shown when the configured mode/grid has never been played.
struct StreaksRecordsEmptyLabel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No games yet")
                .font(.subheadline.bold())
            Text("Tap to play")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
