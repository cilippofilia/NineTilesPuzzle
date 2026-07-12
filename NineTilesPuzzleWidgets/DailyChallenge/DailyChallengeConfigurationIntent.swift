//
//  DailyChallengeConfigurationIntent.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import AppIntents
import WidgetKit

/// User-facing configuration for the Daily Challenge widget, edited via the standard "Edit
/// Widget" sheet. Defaults to the plain brand-gradient watermark; opting in swaps it for today's
/// seeded puzzle photo, masked into the same puzzle-piece silhouette.
struct DailyChallengeConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Daily Challenge"
    static var description = IntentDescription("Today's puzzle at a glance — mode, grid size, and your calendar streak.")

    @Parameter(title: "Show Puzzle Photo", default: false)
    var showsPuzzlePhoto: Bool
}
