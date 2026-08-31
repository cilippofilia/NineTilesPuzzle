//
//  DailyChallengeWidget.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// The Daily Challenge home-screen widget: today's puzzle identity, completion state, and
/// calendar streak. Shares `DailyChallengeProvider`/`DailyChallengeEntry` — see
/// `DailyChallengeViews.swift` for the presentation.
struct DailyChallengeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.dailyChallenge,
            intent: DailyChallengeConfigurationIntent.self,
            provider: DailyChallengeProvider()
        ) { entry in
            DailyChallengeWidgetView(entry: entry)
                .colorScheme(.dark)
        }
        .configurationDisplayName("Daily Challenge")
        .description("Today's puzzle at a glance — mode, grid size, and your calendar streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // Margins are owned by the views themselves (`DailyWidgetMetrics.padding`) so both
        // families inset identically instead of drifting with the system default.
        .contentMarginsDisabled()
    }
}

// See DailyChallengeViews.swift for the #Preview blocks — colocated with the views they render
// so Xcode's canvas works while editing that file directly.
