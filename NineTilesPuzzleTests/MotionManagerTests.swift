//
//  MotionManagerTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/28/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

/// Verifies the gravity → normalized-tilt mapping that gives the Wall of Fame its
/// "natural gravity" feel. The math is decoupled from `CoreMotion`, so these run
/// without a device. (Live sensor streaming is the pull model and can only be
/// confirmed on hardware.)
@Suite("MotionManager gravity mapping")
struct MotionManagerTests {
    private let clamp = MotionManager.clampRadians

    // MARK: - Roll references true vertical (the gravity feel)

    @Test("Held upright in portrait rests at zero roll")
    func uprightIsZeroRoll() {
        // Upright portrait: gravity points toward the bottom of the device.
        let roll = MotionManager.normalizedRoll(gravityX: 0, gravityY: -1)
        #expect(abs(roll) < 1e-9)
    }

    @Test("Tilting the top to the right yields positive roll")
    func tiltRightIsPositive() {
        // Device rotated clockwise by θ: gravity gains a +x component.
        let theta = clamp / 2
        let roll = MotionManager.normalizedRoll(gravityX: sin(theta), gravityY: -cos(theta))
        #expect(roll > 0)
        #expect(abs(roll - 0.5) < 1e-9) // half the clamp → half deflection
    }

    @Test("Tilting the top to the left yields negative roll")
    func tiltLeftIsNegative() {
        let theta = clamp / 2
        let roll = MotionManager.normalizedRoll(gravityX: -sin(theta), gravityY: -cos(theta))
        #expect(roll < 0)
        #expect(abs(roll + 0.5) < 1e-9)
    }

    @Test("Roll saturates to ±1 beyond the clamp angle")
    func rollClampsAtExtremes() {
        let pastClamp = clamp * 4
        let right = MotionManager.normalizedRoll(gravityX: sin(pastClamp), gravityY: -cos(pastClamp))
        let left = MotionManager.normalizedRoll(gravityX: -sin(pastClamp), gravityY: -cos(pastClamp))
        #expect(right == 1)
        #expect(left == -1)
    }

    @Test("Exactly the clamp angle maps to full deflection")
    func rollReachesUnitAtClamp() {
        let roll = MotionManager.normalizedRoll(gravityX: sin(clamp), gravityY: -cos(clamp))
        #expect(abs(roll - 1) < 1e-9)
    }

    @Test("Lying flat on a table produces no roll jitter")
    func flatOnTableIsZeroRoll() {
        // Face-up flat: gravity points straight out the back (−z), no screen-plane
        // tilt. Without the near-flat guard, atan2(0, -0) == π would slam roll to 1.
        #expect(MotionManager.normalizedRoll(gravityX: 0, gravityY: 0) == 0)
        // Real sensors never read exactly zero; tiny noise must not deflect either.
        #expect(MotionManager.normalizedRoll(gravityX: 0.01, gravityY: -0.01) == 0)
        #expect(MotionManager.normalizedRoll(gravityX: -0.02, gravityY: 0.01) == 0)
    }

    // MARK: - Pitch

    @Test("Held upright in portrait rests at zero pitch")
    func uprightIsZeroPitch() {
        let pitch = MotionManager.normalizedPitch(gravityX: 0, gravityY: -1, gravityZ: 0)
        #expect(abs(pitch) < 1e-9)
    }

    @Test("Leaning the top back yields positive pitch and clamps")
    func leanBackIsPositivePitch() {
        let theta = clamp / 2
        // Tipping the top back toward face-up moves gravity into −z; at a full 90°
        // the device is flat face-up with gravity straight out the back (−z).
        let pitch = MotionManager.normalizedPitch(gravityX: 0, gravityY: -cos(theta), gravityZ: -sin(theta))
        #expect(pitch > 0)
        #expect(abs(pitch - 0.5) < 1e-9)

        let flatFaceUp = MotionManager.normalizedPitch(gravityX: 0, gravityY: 0, gravityZ: -1)
        #expect(flatFaceUp == 1)
    }
}
