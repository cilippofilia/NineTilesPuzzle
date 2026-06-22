//
//  LimitedMovesRules.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/22/26.
//

import Foundation

/// Pure game-design constant for Limited Moves mode, kept free of `GameSession` so it's
/// trivially unit-testable. MVP scope: a flat per-grid-size move budget — every move costs
/// exactly 1, regardless of whether it locks a tile correctly.
enum LimitedMovesRules {
    /// Total moves allowed for a fresh Limited Moves puzzle at `gridSize`.
    static func moveBudget(forGridSize gridSize: Int) -> Int {
        switch gridSize {
        case 3: 12
        case 4: 24
        case 5: 40
        case 6: 60
        case 7: 85
        default: 115 // covers 8 and any larger size
        }
    }
}
