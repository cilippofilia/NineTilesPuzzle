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
        #expect(LimitedMovesRules.moveBudget(forGridSize: 3) == 10)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 4) == 20)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 5) == 34)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 6) == 50)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 7) == 70)
        #expect(LimitedMovesRules.moveBudget(forGridSize: 8) == 95)
    }

    @Test func moveBudgetFallsBackToTheLargestTierBeyondEightByEight() {
        #expect(LimitedMovesRules.moveBudget(forGridSize: 9) == 95)
    }
}
