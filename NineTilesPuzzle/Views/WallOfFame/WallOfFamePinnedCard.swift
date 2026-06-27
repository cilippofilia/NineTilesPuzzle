//
//  WallOfFamePinnedCard.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// A pre-rendered polaroid card pinned to the Wall of Fame cork board.
///
/// The base angle is seeded per slot so each card rests at a unique tilt.
/// Physics: a spring-damper pendulum simulation runs at 60 fps via `TimelineView`.
/// The device roll (from `MotionManager`) sets the equilibrium angle, and the card
/// swings toward it with inertia — overshooting and oscillating before settling,
/// exactly like a real card hanging from a pin.
struct WallOfFamePinnedCard: View {
    let slot: WallOfFameSlot
    let cardImage: CGImage
    let motionManager: MotionManager

    @State private var swingAngle: Double = 0
    @State private var angularVelocity: Double = 0

    private let stiffness = 0.025
    private let damping   = 0.11

    private var baseAngle: Double {
        let seed = slot.seedValue
        let normalized = Double((seed * 1_000_003) % 13) / 13.0
        return (normalized - 0.5) * 12.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { timeline in
            Image(decorative: cardImage, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 192)
                .clipShape(.rect(cornerRadius: 3))
                .shadow(
                    color: .black.opacity(0.4),
                    radius: 6,
                    x: -swingAngle * 0.5,
                    y: 4
                )
                .overlay(alignment: .top) {
                    Text("📍")
                        .font(.title3)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .padding(.top, -8)
                }
                .rotationEffect(.degrees(baseAngle + swingAngle), anchor: .top)
                .onChange(of: timeline.date) { _, _ in
                    stepPhysics()
                }
        }
    }

    private func stepPhysics() {
        let targetAngle = -motionManager.roll * 6.0
        let springForce  = (targetAngle - swingAngle) * stiffness
        let dampingForce = -angularVelocity * damping
        angularVelocity += springForce + dampingForce
        swingAngle      += angularVelocity
    }
}
