//
//  DailySmallView.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// Small home-screen card: minimal wordmark header, a hero-sized grid readout (or solved seal),
/// and a big brand-gradient flame rising from the bottom edge marking the streak.
struct DailySmallView: View {
    let entry: DailyChallengeEntry

    var body: some View {
        VStack(alignment: .leading) {
            DailyHeaderLabel()

            if entry.isCompletedToday {
                DailyHeroRow(title: Text("Solved"), subtitle: "Come back tomorrow") {
                    SolvedSeal(size: 30)
                }
            } else {
                DailyHeroRow(
                    title: Text("\(entry.gridSize)×\(entry.gridSize)").foregroundStyle(BrandGradient.diagonal),
                    subtitle: entry.mode.title.uppercased()
                ) {
                    ModeIconChip(icon: entry.mode.icon, size: 30)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) {
            ZStack {
                DailyWidgetBackground(showsWatermark: false, imageData: entry.imageData)
                DailyStreakFlame(streak: entry.streak, isCompletedToday: entry.isCompletedToday, isFrozen: entry.isFrozen)
            }
        }
    }
}

#Preview("Small", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true
    )
    DailyChallengeEntry(
        date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true
    )
    // No active streak: the flame's "N DAY STREAK" numeral gives way to the "play today's game"
    // nudge — cycle the canvas's timeline scrubber to reach this third entry.
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 0, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true
    )
}

/// Long-running streaks push `DailyStreakFlame` to its size cap — this catches clipping that a
/// low mock streak (like the "Small" preview above) never would.
#Preview("Small — High Streak", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 20, bestStreak: 20, gridSize: 4, mode: .slide, imageData: nil, isPremiumUnlocked: true)
}

/// A Picsum outage froze today rather than breaking the streak: the flame swaps for a snowflake
/// (lit blue instead of the usual unlit-grey "not completed today" look).
#Preview("Small — Frozen Streak", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true, isFrozen: true
    )
}
