//
//  DailyUpgradeView.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// Shown instead of today's puzzle state when the player hasn't unlocked premium — Home
/// Screen widgets are an "Always Connected" system-integration upsell (`PremiumFeature.widgets`),
/// not a preview of the Daily Challenge itself. Tapping deep-links straight to the paywall.
struct DailyUpgradeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DailyHeaderLabel()

            Spacer()

            Label("Upgrade to VIP", systemImage: "lock.fill")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Resume games and track your streak from the Home Screen.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) {
            DailyWidgetBackground(imageData: nil)
        }
    }
}

#Preview("Locked", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: false
    )
}
