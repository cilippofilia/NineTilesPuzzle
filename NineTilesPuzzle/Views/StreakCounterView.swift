//
//  StreakCounterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct StreakCounterView: View {
    let currentStreak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(currentStreak > 0 ? .orange : .secondary)
            Text("\(currentStreak)")
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStreak)
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakCounterView(currentStreak: 0)
        StreakCounterView(currentStreak: 5)
        StreakCounterView(currentStreak: 42)
    }
}
