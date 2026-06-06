//
//  MoveCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct MoveCounterView: View {
    let moves: Int
    var personalBest: Int? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
                Text("\(moves)")
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            if let best = personalBest {
                Text("Best: \(best)")
                    .font(.caption2)
                    .foregroundStyle(moves < best ? .orange : .secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: moves)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: personalBest)
    }
}

#Preview {
    VStack(spacing: 16) {
        MoveCounterView(moves: 0)
        MoveCounterView(moves: 42, personalBest: 38)
        MoveCounterView(moves: 35, personalBest: 38)
    }
}
