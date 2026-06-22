//
//  LimitedMovesRulesTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/22/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("LimitedMovesRules")
struct LimitedMovesRulesTests {
    @Test func moveBudgetMatchesTheSpecForEveryGridSize() {
        #expect(LimitedMovesRules.moveBudget(forGridSize: 3) == 12)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 4) == 24)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 5) == 40)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 6) == 60)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 7) == 85)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 8) == 115)
    }

    @Test func moveBudgetFallsBackToTheLargestTierBeyondEightByEight() {
        #expect(LimitedMovesRules.moveBudget(forGridSize: 9) == 115)
    }
}
