//
//  WallOfFamePinnedCard.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// A pre-rendered polaroid card pinned to the Wall of Fame cork board.
///
/// The base angle is seeded per slot so each card rests at a unique tilt. On top
/// of it sits a spring-damper pendulum whose equilibrium follows the device's
/// tilt relative to real-world gravity (via `MotionManager`), so cards hang
/// toward true "down" and oscillate before settling, like a card on a pin.
///
/// All cards share one physics tick from `WallOfFameSwingEngine`: this view
/// registers its `CardSwing` while on screen and reads only that swing's `angle`,
/// so it re-renders solely while it is actually moving.
struct WallOfFamePinnedCard: View {
    let slot: WallOfFameSlot
    let cardImage: CGImage
    let engine: WallOfFameSwingEngine

    @State private var swing = CardSwing()

    private var baseAngle: Double {
        let seed = slot.seedValue
        let normalized = Double((seed * 1_000_003) % 13) / 13.0
        return (normalized - 0.5) * 12.0
    }

    var body: some View {
        Image(decorative: cardImage, scale: 1)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 192)
            .clipShape(.rect(cornerRadius: 3))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
            .overlay(alignment: .top) {
                Text("📍")
                    .font(.title3)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .padding(.top, -8)
            }
            .rotationEffect(.degrees(baseAngle + swing.angle), anchor: .top)
            .onAppear { engine.register(swing) }
            .onDisappear { engine.unregister(swing) }
    }
}
