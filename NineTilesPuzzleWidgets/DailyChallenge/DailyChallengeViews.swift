//
//  DailyChallengeViews.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

/// Family switch for the Daily Challenge widget. The whole widget is one destination, so a
/// single `widgetURL` covers every family.
struct DailyChallengeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyChallengeEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                DailyMediumView(entry: entry)
            default:
                DailySmallView(entry: entry)
            }
        }
        .widgetURL(DeepLink.daily.url)
    }
}

/// Small home-screen card: header, today's state (done vs mode + grid), and the streak flame.
struct DailySmallView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DailyHeaderLabel()

            Spacer(minLength: 0)

            if entry.isCompletedToday {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                    .widgetAccentable()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Label("\(entry.gridSize) × \(entry.gridSize)", systemImage: entry.mode.icon)
                        .font(.title3.bold())
                        .widgetAccentable()
                    Text(entry.mode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                StatBadge(icon: "flame.fill", text: "\(entry.streak)", accent: accent)
                if entry.bestStreak > 0 {
                    StatBadge(icon: "trophy.fill", text: "\(entry.bestStreak)", accent: .yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// Medium home-screen card: date and today's puzzle identity on the left, completion state
/// and streak pills on the right.
struct DailyMediumView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                DailyHeaderLabel()
                Text(entry.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.headline)
                Label("\(entry.mode.title) · \(entry.gridSize) × \(entry.gridSize)", systemImage: entry.mode.icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                if entry.isCompletedToday {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .widgetAccentable()
                } else {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(accent)
                        .widgetAccentable()
                }
                StatBadge(icon: "flame.fill", text: "\(entry.streak) day streak", accent: accent)
                if entry.bestStreak > 0 {
                    StatBadge(icon: "trophy.fill", text: "Best \(entry.bestStreak)", accent: .yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// The widget family's shared "Daily" header — brand gradient calendar glyph plus title.
struct DailyHeaderLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.caption.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
                )
            Text("Daily Challenge")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .widgetAccentable()
    }
}

/// The dark card background shared by the daily widget's home-screen families, matching the
/// Live Activity's dimmed-black look.
struct DailyWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(white: 0.06), Color(white: 0.14)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
