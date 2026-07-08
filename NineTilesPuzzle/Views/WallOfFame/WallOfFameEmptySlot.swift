//
//  WallOfFameEmptySlot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// A placeholder for a slot on the Wall of Fame that has not yet been earned.
/// Renders a dashed rounded-rect border so the board feels like something to fill in.
struct WallOfFameEmptySlot: View {
    let slot: WallOfFameSlot

    @Environment(StatsStore.self) private var statsStore

    /// Gauntlet Ladder stages are sequential, so an empty stage slot can mean two different
    /// things: the player hasn't reached it yet ("locked"), or they have but no card was
    /// captured — e.g. a Numbers-media clear, which has no photo to pin. `+ 1` keeps the
    /// very next stage in reach from reading as locked; every other slot category is never
    /// locked, since it isn't gated behind clearing anything else first.
    private var isLocked: Bool {
        guard case .ladderStage(let stage) = slot else { return false }
        return stage > statsStore.bestLadderStageReached + 1
    }

    private var bottomText: String {
        isLocked ? "Locked" : slot.displayTitle
    }

    var body: some View {
        Rectangle()
            .stroke(
                Color.white.opacity(0.001),
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
            .frame(width: 160, height: 192)
            .background(.ultraThinMaterial.opacity(0.6))
            .overlay {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .bottom) {
                Text(bottomText)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(6)
            }
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    HStack(spacing: 20) {
        WallOfFameEmptySlot(slot: .ladderStage(1))
        WallOfFameEmptySlot(slot: .ladderStage(10))
    }
    .padding(40)
    .background(Color.black)
    .environment(StatsStore())
}
