//
//  DailyChallengeWidgetAlt.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// A second, design-forward Daily Challenge widget registered under its own kind so it can be
/// placed on the home screen next to the original for a side-by-side comparison. Shares
/// `DailyChallengeProvider`/`DailyChallengeEntry` — only the presentation differs.
struct DailyChallengeWidgetAlt: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.dailyChallengeAlt, provider: DailyChallengeProvider()) { entry in
            DailyChallengeAltWidgetView(entry: entry)
                .colorScheme(.dark)
        }
        .configurationDisplayName("Daily Challenge (Alt)")
        .description("A design-forward take on the Daily Challenge widget, for comparison.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// See DailyChallengeAltViews.swift for the #Preview blocks — colocated with the views they render
// so Xcode's canvas works while editing that file directly.
