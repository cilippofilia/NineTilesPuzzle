//
//  WallOfFameSwingEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/28/26.
//

import Observation

/// Advances every visible Wall of Fame card's pendulum from a single 60 fps tick,
/// replacing the previous per-card `TimelineView`s. Cards register their
/// `CardSwing` while on screen; `step(roll:)` advances all of them at once and
/// writes each card's `angle` only when it actually moves, so settled cards stop
/// re-rendering until the next tilt.
@MainActor
@Observable
final class WallOfFameSwingEngine {
    @ObservationIgnored private var swings: [ObjectIdentifier: CardSwing] = [:]

    @ObservationIgnored private let stiffness = 0.025
    @ObservationIgnored private let damping = 0.11
    /// Below this much motion (degrees) a card is settled and skips its state write.
    /// Half a degree of resting tilt is imperceptible on a pinned card, and the looser the
    /// window the sooner cards stop re-rendering; the previous 0.01 combined with a raw
    /// roll target meant they effectively never rested.
    @ObservationIgnored private let restThreshold = 0.5
    /// Device roll (−1…1) maps to this many degrees of equilibrium swing.
    @ObservationIgnored private let rollToDegrees = 6.0
    /// Roll is quantized to steps of this size before becoming a target. A hand-held
    /// device's roll never sits perfectly still, so an unquantized target kept nudging
    /// every card's equilibrium each tick — no card ever settled, and all of them
    /// re-rendered at 60fps for as long as the wall was on screen.
    @ObservationIgnored private let rollStep = 0.02

    /// Starts advancing `swing` on each `step`. Keyed by identity, so calling it
    /// more than once for the same instance is a harmless no-op.
    func register(_ swing: CardSwing) {
        swings[ObjectIdentifier(swing)] = swing
    }

    /// Stops advancing `swing` (call when its card scrolls off or disappears).
    func unregister(_ swing: CardSwing) {
        swings[ObjectIdentifier(swing)] = nil
    }

    /// Advances every registered card one frame toward the gravity-driven target.
    func step(roll: Double) {
        let quantizedRoll = (roll / rollStep).rounded() * rollStep
        let target = -quantizedRoll * rollToDegrees
        for swing in swings.values {
            let springForce  = (target - swing.angle) * stiffness
            let dampingForce = -swing.velocity * damping
            let newVelocity  = swing.velocity + springForce + dampingForce
            let newAngle     = swing.angle + newVelocity

            // Settled: skip the observed `angle` write so the card isn't
            // re-rendered. Checking distance-to-target (not just velocity) avoids
            // freezing at a swing's apex, where velocity is momentarily zero.
            if abs(newVelocity) < restThreshold && abs(target - newAngle) < restThreshold {
                if swing.velocity != 0 { swing.velocity = 0 }
                continue
            }
            swing.velocity = newVelocity
            swing.angle = newAngle
        }
    }
}
