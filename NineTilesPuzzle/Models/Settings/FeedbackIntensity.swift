//
//  FeedbackIntensity.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import SwiftUI

/// A single "how much do you want to feel this" dial covering both haptics and sound
/// volume. SwiftUI's `SensoryFeedback` only exposes an adjustable `intensity` on
/// `.impact(...)` — the semantic patterns (`.success`, `.warning`, `.error`) are fixed by
/// the Taptic Engine — so `Subtle` downgrades those to the lighter `.selection` pattern
/// rather than trying to soften a type that has no volume knob.
enum FeedbackIntensity: String, CaseIterable, Identifiable, Codable {
    case off
    case subtle
    case standard
    case strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .standard: "Standard"
        case .strong: "Strong"
        }
    }

    /// Shared multiplier for impact-haptic intensity and sound playback volume.
    var scale: Double {
        switch self {
        case .off: 0
        case .subtle: 0.35
        case .standard: 0.7
        case .strong: 1.0
        }
    }

    /// A discrete "thud" moment — tile lock, shutter fire — scaled by level. `nil` plays
    /// nothing, which both `.off` and a `false` trigger condition should resolve to.
    func impactFeedback(flexibility: SensoryFeedback.Flexibility = .rigid) -> SensoryFeedback? {
        guard self != .off else { return nil }
        return .impact(flexibility: flexibility, intensity: scale)
    }

    /// A semantic outcome — win, streak break, failure — downgraded to `.selection` at
    /// Subtle since the semantic patterns themselves can't be softened.
    func semanticFeedback(_ feedback: SensoryFeedback) -> SensoryFeedback? {
        switch self {
        case .off: nil
        case .subtle: .selection
        case .standard, .strong: feedback
        }
    }

    /// The lightest system pattern, used for incidental ticks (countdown steps).
    var selectionFeedback: SensoryFeedback? {
        self == .off ? nil : .selection
    }
}
