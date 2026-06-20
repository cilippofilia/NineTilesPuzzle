//
//  TimeTrialTimerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// Time Trial's countdown display: mm:ss, recoloring per the spec's own thresholds (white
/// → yellow at 20s → deep red at 10s) — distinct from `StreakCounterView`'s 15s/7s
/// thresholds, since Time Trial's base limits run much longer (up to 180s).
struct TimeTrialTimerView: View {
    let remaining: Double

    private var color: Color {
        if remaining > 20 { return .primary }
        if remaining > 10 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .foregroundStyle(color)
            Text(max(0, remaining).formattedMinutesSeconds)
                .bold()
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: remaining)
    }
}

#Preview {
    VStack(spacing: 16) {
        TimeTrialTimerView(remaining: 45)
        TimeTrialTimerView(remaining: 18)
        TimeTrialTimerView(remaining: 6)
    }
}
