//
//  MotionManager.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import CoreMotion

/// Exposes device tilt relative to real-world gravity as normalized pitch and
/// roll (−1…1, clamped at ±0.14 rad ≈ ±8°). Used by the Wall of Fame tilt effect
/// and will also drive Gravity Mode when that feature ships.
///
/// Gravity-referenced, pull model: `roll`/`pitch` are derived on demand from
/// `CMDeviceMotion.gravity`, the accelerometer-fused vector that always points at
/// true "down" (and, unlike integrated attitude, does not drift). Updates are
/// pulled from `manager.deviceMotion` inside the caller's render loop rather than
/// pushed on an operation queue, so heavy UI work (the Wall of Fame runs many
/// 60 fps `TimelineView`s at once) can never starve delivery and freeze the tilt.
@MainActor
@Observable
final class MotionManager {
    private let manager = CMMotionManager()

    /// Tilt magnitude (radians) mapped to the full ±1 normalized range. ≈ 8°.
    nonisolated static let clampRadians = 0.14
    private let updateInterval = 1.0 / 60.0

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Normalized roll (left-right tilt vs. vertical), −1…1. Zero when the device
    /// is held upright in portrait; swings toward whichever side faces real down.
    var roll: Double {
        guard let gravity = manager.deviceMotion?.gravity else { return 0 }
        return Self.normalizedRoll(gravityX: gravity.x, gravityY: gravity.y)
    }

    /// Normalized pitch (front-back lean vs. vertical), −1…1. Kept for parity and
    /// future parallax use; the pinned-card effect only consumes `roll`.
    var pitch: Double {
        guard let gravity = manager.deviceMotion?.gravity else { return 0 }
        return Self.normalizedPitch(gravityX: gravity.x, gravityY: gravity.y, gravityZ: gravity.z)
    }

    /// Below this much screen-plane gravity the device is essentially flat, where
    /// the left-right roll angle is undefined and noise-dominated. Treat as level.
    private nonisolated static let minPlanarGravity = 0.05

    /// Maps the screen-plane gravity components to a normalized, clamped roll.
    /// Pure and `CoreMotion`-free so the gravity-feel mapping stays unit-testable.
    nonisolated static func normalizedRoll(gravityX x: Double, gravityY y: Double) -> Double {
        // Near-flat: screen-plane gravity is tiny, so atan2 is ill-defined and
        // jittery (and atan2(0, -0) == π). Rest level instead of slamming sideways.
        guard hypot(x, y) > minPlanarGravity else { return 0 }
        return max(-1, min(1, atan2(x, -y) / clampRadians))
    }

    /// Maps the gravity vector to a normalized, clamped front-back pitch. Pure and
    /// `CoreMotion`-free so it can be unit-tested without a device.
    nonisolated static func normalizedPitch(gravityX x: Double, gravityY y: Double, gravityZ z: Double) -> Double {
        max(-1, min(1, atan2(-z, hypot(x, y)) / clampRadians))
    }

    func startUpdates() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = updateInterval
        // Pull model: no handler. Samples accumulate in `manager.deviceMotion`,
        // read on demand by `roll`/`pitch` from the main-thread render loop.
        manager.startDeviceMotionUpdates()
    }

    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
    }
}
