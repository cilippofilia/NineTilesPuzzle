//
//  GauntletLadderRulesTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/20/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("GauntletLadderRules")
struct GauntletLadderRulesTests {
    // MARK: - stage table

    @Test func stagesTableMatchesTheSpecForEveryStage() {
        let expected: [(gridSize: Int, baseTimeLimit: TimeInterval, multiplier: Double)] = [
            (3, 45, 1.0),
            (3, 40, 1.1),
            (4, 45, 1.3),
            (4, 40, 1.5),
            (5, 75, 2.0),
            (5, 70, 2.2),
            (6, 110, 2.8),
            (7, 140, 3.5),
            (8, 180, 4.2),
            (8, 165, 5.0),
        ]

        #expect(GauntletLadderRules.stages.count == GauntletLadderRules.stageCount)
        for (index, row) in expected.enumerated() {
            let stage = GauntletLadderRules.stages[index]
            #expect(stage.number == index + 1)
            #expect(stage.gridSize == row.gridSize)
            #expect(stage.baseTimeLimit == row.baseTimeLimit)
            #expect(stage.difficultyMultiplier == row.multiplier)
        }
    }

    @Test func stageLookupIsOneIndexed() {
        #expect(GauntletLadderRules.stage(1).number == 1)
        #expect(GauntletLadderRules.stage(1).gridSize == 3)
        #expect(GauntletLadderRules.stage(10).number == 10)
        #expect(GauntletLadderRules.stage(10).gridSize == 8)
    }

    // MARK: - stageScore

    @Test func stageScoreScalesWithDifficultyMultiplier() {
        let stage1 = GauntletLadderRules.stage(1) // multiplier 1.0
        let stage5 = GauntletLadderRules.stage(5) // multiplier 2.0
        #expect(GauntletLadderRules.stageScore(remainingSeconds: 10, stage: stage1, currentWinStreak: 0) == 1000)
        #expect(GauntletLadderRules.stageScore(remainingSeconds: 10, stage: stage5, currentWinStreak: 0) == 2000)
    }

    @Test func stageScoreIncreasesWithWinStreak() {
        let stage = GauntletLadderRules.stage(1)
        let noStreak = GauntletLadderRules.stageScore(remainingSeconds: 10, stage: stage, currentWinStreak: 0)
        let withStreak = GauntletLadderRules.stageScore(remainingSeconds: 10, stage: stage, currentWinStreak: 5)
        #expect(noStreak == 1000)
        // (1 + 5/10) = 1.5x
        #expect(withStreak == 1500)
        #expect(withStreak > noStreak)
    }

    @Test func stageScoreIsZeroWithNoTimeRemaining() {
        let stage = GauntletLadderRules.stage(7)
        #expect(GauntletLadderRules.stageScore(remainingSeconds: 0, stage: stage, currentWinStreak: 3) == 0)
    }
}
