//
//  DailyChallengeWidgetView.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// Family switch for the Daily Challenge widget: a glowing brand-gradient watermark, a
/// calendar-page date chip, and gradient hero numerals throughout. The whole widget is one
/// destination, so a single `widgetURL` covers every family.
struct DailyChallengeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyChallengeEntry

    var body: some View {
        Group {
            if !entry.isPremiumUnlocked {
                DailyUpgradeView()
            } else {
                switch family {
                case .systemMedium:
                    DailyMediumView(entry: entry)
                default:
                    DailySmallView(entry: entry)
                }
            }
        }
        .widgetURL(entry.isPremiumUnlocked ? DeepLink.daily.url : DeepLink.paywall.url)
    }
}

/// Layout constants shared by both families so their edges align when placed side by side.
enum DailyWidgetMetrics {
    /// One padding for every edge of both the small and medium cards — the system content
    /// margins are disabled on the widget configuration in favor of this.
    static let padding: CGFloat = 14

    /// Shown in place of the streak flame/piece row when `streak == 0` — same copy in both
    /// families so a player sees one consistent nudge regardless of which size they've placed.
    static let noStreakPrompt = "Play today's game to start a streak"
}

/// Shared red→yellow brand gradient used across the widget's hero elements.
enum BrandGradient {
    static let diagonal = LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
}
