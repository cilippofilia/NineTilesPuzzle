//
//  MoveCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct MoveCounterView: View {
    let moves: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(.secondary)
            Text("\(moves)")
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: moves)
    }
}

#Preview {
    VStack(spacing: 16) {
        MoveCounterView(moves: 0)
        MoveCounterView(moves: 42)
    }
}
