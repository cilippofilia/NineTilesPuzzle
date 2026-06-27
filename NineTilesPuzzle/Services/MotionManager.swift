//
//  MotionManager.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import CoreMotion

/// Streams device attitude (pitch and roll) from `CMMotionManager`, normalized
/// to a −1…1 range clamped at ±0.14 rad (≈ ±8°). Used by the Wall of Fame tilt
/// effect and will also drive Gravity Mode when that feature ships.
///
/// Calibration: the first attitude reading after `startUpdates()` is captured as
/// the neutral reference via `multiply(byInverseOf:)`. This means whatever
/// orientation the device is in when the view appears is treated as "zero" — cards
/// sit straight regardless of the absolute device attitude.
@MainActor
@Observable
final class MotionManager {
    private let manager = CMMotionManager()
    /// Normalized pitch (front-back tilt), −1…1.
    private(set) var pitch: Double = 0
    /// Normalized roll (left-right tilt), −1…1.
    private(set) var roll: Double = 0

    private var referenceAttitude: CMAttitude?

    private let clampRadians = 0.14  // ≈ 8°
    private let updateInterval = 1.0 / 30.0

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func startUpdates() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        referenceAttitude = nil
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // First reading becomes the neutral reference — all subsequent deltas
            // are measured relative to it so the starting orientation = roll/pitch 0.
            if self.referenceAttitude == nil {
                self.referenceAttitude = motion.attitude.copy() as? CMAttitude
            }
            if let ref = self.referenceAttitude {
                motion.attitude.multiply(byInverseOf: ref)
            }
            let clamp = self.clampRadians
            self.pitch = (motion.attitude.pitch / clamp).clamped(to: -1...1)
            self.roll  = (motion.attitude.roll  / clamp).clamped(to: -1...1)
        }
    }

    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
        referenceAttitude = nil
        pitch = 0
        roll = 0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
