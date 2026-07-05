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
        RoundedRectangle(cornerRadius: 4)
            .stroke(
                Color.white.opacity(isLocked ? 0.12 : 0.25),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .frame(width: 160, height: 192)
            .overlay {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .overlay(alignment: .bottom) {
                Text(bottomText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(isLocked ? 0.25 : 0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
            }
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
