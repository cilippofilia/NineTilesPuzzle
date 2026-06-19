//
//  TimeCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import SwiftUI

struct TimeCounterView: View {
    let elapsed: TimeInterval
    var personalBest: TimeInterval? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text(elapsed.formattedMinutesSeconds)
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())
            if let best = personalBest {
                Text("/ \(best.formattedMinutesSeconds)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: elapsed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: personalBest)
    }
}

#Preview {
    VStack(spacing: 16) {
        TimeCounterView(elapsed: 0)
        TimeCounterView(elapsed: 42, personalBest: 38)
        TimeCounterView(elapsed: 35, personalBest: 38)
    }
}
