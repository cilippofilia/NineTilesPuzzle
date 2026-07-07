//
//  TimeTrialRulesTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/20/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("TimeTrialRules")
struct TimeTrialRulesTests {
    // MARK: - baseTimeLimit

    @Test func baseTimeLimitMatchesTheSpecForEveryGridSize() {
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 3) == 35)
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 4) == 35)
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 5) == 60)
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 6) == 90)
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 7) == 115)
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 8) == 150)
    }

    @Test func baseTimeLimitFallsBackToTheLargestTierBeyondEightByEight() {
        #expect(TimeTrialRules.baseTimeLimit(forGridSize: 9) == 150)
    }

    // MARK: - combo amounts

    @Test func comboBonusAndMisplayPenaltyAreTheSpecsFlatAmounts() {
        #expect(TimeTrialRules.comboBonusSeconds == 1)
        #expect(TimeTrialRules.misplayPenaltySeconds == 2)
    }

    // MARK: - score

    @Test func scoreScalesWithRemainingSecondsAndGridSize() {
        #expect(TimeTrialRules.score(remainingSeconds: 10, gridSize: 3) == 1000)
        #expect(TimeTrialRules.score(remainingSeconds: 10, gridSize: 6) == 2000)
    }

    @Test func scoreIsZeroWithNoTimeRemaining() {
        #expect(TimeTrialRules.score(remainingSeconds: 0, gridSize: 5) == 0)
    }

    @Test func scoreRoundsToTheNearestWholeNumber() {
        // 7.5s * 100 * (4/3) = 1000 exactly; pick a case that needs real rounding.
        #expect(TimeTrialRules.score(remainingSeconds: 1, gridSize: 4) == 133)
    }
}
