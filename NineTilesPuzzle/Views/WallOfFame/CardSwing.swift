//
//  CardSwing.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/28/26.
//

import Observation

/// Per-card spring-pendulum state for the Wall of Fame tilt effect.
///
/// `angle` is observed so a card re-renders only when its own swing changes,
/// while `velocity` is integration-only and ignored by observation — stepping it
/// every frame never invalidates a view. `WallOfFameSwingEngine` advances these.
@MainActor
@Observable
final class CardSwing {
    /// Current swing offset in degrees, added to the card's seeded base angle.
    var angle: Double = 0

    /// Angular velocity (degrees/frame); internal to the simulation.
    @ObservationIgnored var velocity: Double = 0
}
