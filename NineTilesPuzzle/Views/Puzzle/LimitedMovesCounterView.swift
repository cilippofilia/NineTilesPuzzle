//
//  LimitedMovesCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/22/26.
//

import SwiftUI

/// Limited Moves' "moves left" pill, recoloring by the *fraction* of budget remaining
/// (white above 50%, yellow above 25%, red below) rather than a fixed count — unlike Time
/// Trial's fixed-second thresholds, the budget itself ranges from 12 to 115+ across grid
/// sizes, so a fraction is the only threshold that means the same thing at every size.
struct LimitedMovesCounterView: View {
    let remaining: Int
    let budget: Int

    private var fraction: Double { budget > 0 ? Double(remaining) / Double(budget) : 0 }

    private var color: Color {
        if fraction > 0.5 { return .primary }
        if fraction > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .foregroundStyle(color)
            Text("\(remaining)")
                .bold()
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: true))
            Text("left")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: remaining)
    }
}

#Preview {
    VStack(spacing: 16) {
        LimitedMovesCounterView(remaining: 12, budget: 12)
        LimitedMovesCounterView(remaining: 5, budget: 12)
        LimitedMovesCounterView(remaining: 2, budget: 12)
    }
}
