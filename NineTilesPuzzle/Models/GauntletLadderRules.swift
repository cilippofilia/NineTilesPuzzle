//
//  GauntletLadderRules.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import Foundation

/// Pure game-design constants and formulas for Time Trial's Gauntlet Ladder sub-mode: a
/// fixed 10-stage progression of escalating grid size, time limit, and difficulty
/// multiplier. Kept separate from `TimeTrialRules` — that file's single-puzzle formula is
/// already shipped and recorded in players' personal bests, and the ladder's formula only
/// makes sense once a real cross-puzzle win streak exists, so the two are deliberately
/// distinct concerns rather than one function with an awkward parameter combination.
enum GauntletLadderRules {
    struct Stage {
        let number: Int
        let gridSize: Int
        let baseTimeLimit: TimeInterval
        let difficultyMultiplier: Double
    }

    static let stageCount = 10

    /// 1-indexed table from the spec; `stages[0]` is Stage 1.
    static let stages: [Stage] = [
        Stage(number: 1, gridSize: 3, baseTimeLimit: 60, difficultyMultiplier: 1.0),
        Stage(number: 2, gridSize: 3, baseTimeLimit: 50, difficultyMultiplier: 1.1),
        Stage(number: 3, gridSize: 4, baseTimeLimit: 60, difficultyMultiplier: 1.3),
        Stage(number: 4, gridSize: 4, baseTimeLimit: 55, difficultyMultiplier: 1.5),
        Stage(number: 5, gridSize: 5, baseTimeLimit: 100, difficultyMultiplier: 2.0),
        Stage(number: 6, gridSize: 5, baseTimeLimit: 90, difficultyMultiplier: 2.2),
        Stage(number: 7, gridSize: 6, baseTimeLimit: 140, difficultyMultiplier: 2.8),
        Stage(number: 8, gridSize: 7, baseTimeLimit: 180, difficultyMultiplier: 3.5),
        Stage(number: 9, gridSize: 8, baseTimeLimit: 240, difficultyMultiplier: 4.2),
        Stage(number: 10, gridSize: 8, baseTimeLimit: 210, difficultyMultiplier: 5.0),
    ]

    /// `stages[stageNumber - 1]`; traps on out-of-range like `Array` subscript would —
    /// callers (`GameSession`) are responsible for keeping `currentLadderStage` in 1...10.
    static func stage(_ stageNumber: Int) -> Stage {
        stages[stageNumber - 1]
    }

    /// Per-stage score: rewards remaining time, scaled by the stage's own difficulty
    /// multiplier and boosted by the run's current win streak. `currentWinStreak` is the
    /// number of stages already cleared *before* this one (Stage 1 clears at streak 0).
    static func stageScore(remainingSeconds: TimeInterval, stage: Stage, currentWinStreak: Int) -> Int {
        Int((remainingSeconds * 100 * stage.difficultyMultiplier * (1 + Double(currentWinStreak) / 10)).rounded())
    }
}
