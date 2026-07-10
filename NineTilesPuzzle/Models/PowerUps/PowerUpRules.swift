//
//  PowerUpRules.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import Foundation

/// Tuning constants for the power-up economy — how long a Peek/Hint lasts, how often a
/// streak milestone mints a new power-up, and how many of each type a player starts with.
enum PowerUpRules {
    static let peekDuration: TimeInterval = 3
    static let hintDuration: TimeInterval = 2.5
    static let streakMilestoneInterval = 5
    /// Every power-up type starts at this count on a fresh install, and this is what a debug
    /// "refill" resets back to.
    static let startingInventory = 3
}
