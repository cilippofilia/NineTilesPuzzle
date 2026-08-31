//
//  DailyStreakBadge.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A flame- or trophy-and-count capsule marking the streak's current/best length — echoes the
/// same badge pattern used by the in-game Live Activity, styled to match this widget's own
/// `.ultraThinMaterial` header chip rather than the Dynamic Island's translucent one.
struct DailyStreakBadge: View {
    let icon: String
    let count: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text("\(count)")
                .foregroundStyle(.white)
        }
        .font(.system(size: 18, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: .capsule)
    }
}
