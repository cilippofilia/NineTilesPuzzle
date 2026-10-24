//
//  MotionManager.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import CoreMotion
import UIKit

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

    /// Normalized roll (left-right tilt vs. vertical), −1…1. Zero when the screen is
    /// held upright in its current interface orientation (portrait on iPhone, any of the
    /// four on iPad); swings toward whichever side faces real down.
    var roll: Double {
        guard let gravity = manager.deviceMotion?.gravity else { return 0 }
        let screen = Self.screenGravity(gravityX: gravity.x, gravityY: gravity.y, interfaceOrientation: interfaceOrientation)
        return Self.normalizedRoll(gravityX: screen.x, gravityY: screen.y)
    }

    /// The window's current interface orientation. `CMDeviceMotion.gravity` is always in
    /// the device's own portrait axes, so on a rotated iPad it has to be turned into screen
    /// axes first — otherwise landscape reads as a permanent ±90° tilt.
    private var interfaceOrientation: UIInterfaceOrientation {
        UIApplication.shared.connectedScenes.lazy
            .compactMap { $0 as? UIWindowScene }
            .first?.effectiveGeometry.interfaceOrientation ?? .portrait
    }

    /// Rotates device-axis gravity into the axes of a screen shown in `interfaceOrientation`,
    /// so "upright" always means the UI's own up. Pure so the mapping stays unit-testable.
    nonisolated static func screenGravity(
        gravityX: Double,
        gravityY: Double,
        interfaceOrientation: UIInterfaceOrientation
    ) -> (x: Double, y: Double) {
        switch interfaceOrientation {
        case .portraitUpsideDown: (-gravityX, -gravityY)
        case .landscapeLeft: (-gravityY, gravityX)
        case .landscapeRight: (gravityY, -gravityX)
        default: (gravityX, gravityY)
        }
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
