//
//  PowerUpRules.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import Foundation

/// Tuning constants for the power-up economy — how long a Peek lasts, and how often a
/// streak milestone mints a new power-up.
enum PowerUpRules {
    static let peekDuration: TimeInterval = 3
    static let streakMilestoneInterval = 5
}
