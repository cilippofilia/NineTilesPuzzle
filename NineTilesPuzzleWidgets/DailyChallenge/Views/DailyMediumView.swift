//
//  DailyMediumView.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// Medium home-screen card: a torn-calendar-page date chip and mode identity up top, a gradient
/// "Play" pill (or solved seal) alongside them, and a full-width Duolingo-style puzzle-piece
/// streak row — with weekday initials — anchoring the bottom.
struct DailyMediumView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                CalendarPageChip(
                    date: entry.date,
                    chargeFraction: chargeFraction
                )

                VStack(alignment: .leading) {
                    DailyHeaderLabel()

                    HStack {
                        ModeIconChip(icon: entry.mode.icon, size: 26)

                        VStack(alignment: .leading) {
                            Text(entry.mode.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("\(entry.gridSize) × \(entry.gridSize) grid")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Group {
                            if entry.isCompletedToday {
                                SolvedSeal(size: 34)
                            } else {
                                PlayCTAButton()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)

            if entry.streak > 0 {
                HStack(alignment: .lastTextBaseline) {
                    StreakPieceRow(
                        date: entry.date, streak: entry.streak, isCompletedToday: entry.isCompletedToday,
                        accent: entry.isFrozen ? .blue : accent, pieceSize: 18, spacing: 16,
                        showsWeekdayLabels: true, alignment: .leading
                    )

                    DailyStreakBadge(
                        icon: entry.isFrozen ? "snowflake" : "flame.fill",
                        count: entry.streak,
                        accent: entry.isFrozen ? .blue.mix(with: .white, by: 0.25) : accent
                    )
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            } else {
                // Matches StreakPieceRow's own inset (its pieces sit `runHorizontalPadding`/8pt in
                // from the leading edge and `8pt` up from the row's true bottom via the capsule's
                // vertical padding) so the text lands exactly where the row's content would, not
                // where its empty container edge would.
                Text(DailyWidgetMetrics.noStreakPrompt)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) { DailyWidgetBackground(markOffsetX: 75, imageData: entry.imageData) }
    }

    /// The date badge's battery-style charge: pinned full once today is solved, otherwise
    /// stepping down in fifths as the day elapses — the last fifth stays lit as a "time's
    /// running out" cue rather than draining to nothing.
    private var chargeFraction: Double {
        guard !entry.isCompletedToday else { return 1 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: entry.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 1 }
        let dayLength = dayEnd.timeIntervalSince(dayStart)
        guard dayLength > 0 else { return 1 }
        let elapsedFraction = entry.date.timeIntervalSince(dayStart) / dayLength
        let consumedChunks = min(floor(elapsedFraction * 5), 4)
        return 1 - consumedChunks * 0.2
    }
}

#Preview("Medium", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 50, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
    DailyChallengeEntry(
        date: .now, isCompletedToday: true, streak: 60, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
}

/// The streak row's fixed Monday–Sunday week at a few notable lengths: no streak (the "play
/// today's game" fallback text, in place of the row), a short one starting mid-week, one nearing
/// the end of the week, and a full week — cycle the canvas's timeline scrubber to see all four.
#Preview("Medium — Streak Lengths", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 0, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
    for streak in [3, 5, 7] {
        DailyChallengeEntry(
            date: .now, isCompletedToday: true, streak: streak, bestStreak: 12, gridSize: 5, mode: .swap,
            imageData: nil, isPremiumUnlocked: true
        )
    }
}

/// Same frozen-outage state on the medium card: the piece row and badge both swap from the
/// orange flame theme to blue/snowflake.
#Preview("Medium — Frozen Streak", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true, isFrozen: true
    )
}

/// The date badge's battery-style charge at each step through the day — cycle the canvas's
/// timeline scrubber to see all six. The first five are a solved-free day (100% → 20% in fifths);
/// the last shows a solved day pinned full at the same late hour, for contrast.
#Preview("Charge Levels", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    let calendar = Calendar.current
    let today = Date.now
    for hour in [1, 6, 11, 16, 21] {
        DailyChallengeEntry(
            date: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!,
            isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap,
            imageData: nil, isPremiumUnlocked: true
        )
    }
    DailyChallengeEntry(
        date: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!,
        isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
}
