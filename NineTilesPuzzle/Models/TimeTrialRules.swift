//
//  TimeTrialRules.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import Foundation

/// Pure game-design constants and formulas for Time Trial mode, kept free of `GameSession`
/// so they're trivially unit-testable. MVP scope: a single timed puzzle per grid size, with
/// flat combo bonus/misplay penalty amounts rather than the full multi-stage ladder.
enum TimeTrialRules {
    /// Starting countdown for a fresh Time Trial puzzle at `gridSize`, in seconds.
    static func baseTimeLimit(forGridSize gridSize: Int) -> TimeInterval {
        switch gridSize {
        case 3: 45
        case 4: 45
        case 5: 75
        case 6: 110
        case 7: 140
        default: 180 // covers 8 and any larger size
        }
    }

    /// Time refunded to the countdown when a move locks a tile into its correct position.
    static let comboBonusSeconds: TimeInterval = 1

    /// Time deducted from the countdown when a move doesn't lock a tile correctly.
    static let misplayPenaltySeconds: TimeInterval = 2

    /// Score for solving a puzzle with `remainingSeconds` left on the clock. Rewards larger
    /// grids by scaling with `gridSize`; the spec's per-stage difficulty multiplier and
    /// cross-puzzle streak term are deferred until the multi-stage ladder exists.
    static func score(remainingSeconds: TimeInterval, gridSize: Int) -> Int {
        Int((remainingSeconds * 100 * (Double(gridSize) / 3)).rounded())
    }
}
