//
//  EarnedPowerUpBadgeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// The "power-up earned" flourish shown on the completion banner. On appear the power-up's icon
/// morphs into a `+N` badge announcing how many were just awarded, morphs back to the icon, and
/// finally bumps the running inventory count from its old value up to the new total.
///
/// Purely presentational — the inventory itself was already updated by `PowerUpStore.earnRandom()`
/// at solve time; this view just replays that award for the player to see.
struct EarnedPowerUpBadgeView: View {
    let type: PowerUpType
    /// How many of `type` were awarded this game — the number shown in the `+N` badge.
    let amount: Int
    /// The inventory total *after* the award, i.e. what the count settles on once the flourish
    /// finishes. The pre-award value is derived as `finalCount - amount`.
    let finalCount: Int

    private enum Glyph { case icon, plus }

    @State private var glyph: Glyph = .icon
    @State private var showsFinalCount = false

    private var displayedCount: Int {
        showsFinalCount ? finalCount : max(0, finalCount - amount)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                switch glyph {
                case .icon:
                    Image(systemName: type.icon)
                        .font(.title2)
                        .transition(.blurReplace)
                case .plus:
                    Text("+\(amount)")
                        .font(.title3.bold())
                        .monospacedDigit()
                        .transition(.blurReplace)
                }
            }
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if displayedCount > 0 {
                    Text("\(displayedCount)")
                        .font(.caption2.bold())
                        .padding(4)
                        .frame(minWidth: 24)
                        .background(.red, in: .circle)
                        .offset(x: 6, y: -6)
                        .contentTransition(.numericText(value: Double(displayedCount)))
                }
            }

            Text(type.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earned \(amount) \(type.title) power-up\(amount == 1 ? "" : "s")")
        .task { await playFlourish() }
    }

    /// Drives the three-beat sequence: swap the icon for `+N`, swap it back, then raise the count.
    /// Each pause is short enough to feel like a single reward moment but long enough to read.
    private func playFlourish() async {
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.snappy) { glyph = .plus }

        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.snappy) { glyph = .icon }

        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.snappy) { showsFinalCount = true }
    }
}

#Preview {
    HStack(spacing: 24) {
        EarnedPowerUpBadgeView(type: .peek, amount: 1, finalCount: 3)
        EarnedPowerUpBadgeView(type: .hint, amount: 2, finalCount: 2)
    }
    .padding()
}
