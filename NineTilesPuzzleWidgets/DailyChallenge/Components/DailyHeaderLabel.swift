//
//  DailyHeaderLabel.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// A minimal wordmark header — brand glyph plus tracked-out "DAILY PUZZLE".
struct DailyHeaderLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            BrandPuzzleMark(size: 14)
            Text("DAILY PUZZLE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(.secondary)
        }
        .widgetAccentable()
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(.capsule(style: .continuous))
    }
}
