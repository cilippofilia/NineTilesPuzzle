//
//  DailyChallengeCardView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// Menu card for the Daily Challenge. Shows today's date, the player's current
/// calendar streak, and either a "Play" button (if not yet completed today) or
/// a "Done" indicator (if already completed). Tapping the card itself opens the
/// completion-history calendar.
struct DailyChallengeCardView: View {
    @Environment(DailyChallengeStore.self) private var dailyStore
    let onPlay: () -> Void
    let onShowCalendar: () -> Void

    var body: some View {
        Button(action: onShowCalendar) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Daily Challenge", systemImage: "calendar")
                        .font(.headline)
                        .bold()
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if dailyStore.calendarStreak > 0 {
                    Label(
                        "\(dailyStore.calendarStreak)",
                        systemImage: dailyStore.isTodayFrozen ? "snowflake" : "flame.fill"
                    )
                    .foregroundStyle(streakColor)
                    .font(.subheadline)
                    .bold()
                }

                if dailyStore.isDailyCompletedToday {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .labelStyle(.iconOnly)
                } else {
                    Button("Play", action: onPlay)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                Image(systemName: "chevron.forward")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
        .background(.quaternary, in: .rect(cornerRadius: 20))
    }

    private var streakColor: Color {
        if dailyStore.isTodayFrozen { .blue }
        else if dailyStore.isDailyCompletedToday { .orange }
        else { .secondary }
    }
}

#Preview {
    let dailyStore = DailyChallengeStore()
    DailyChallengeCardView(onPlay: {}, onShowCalendar: {})
        .environment(dailyStore)
        .padding()
}
