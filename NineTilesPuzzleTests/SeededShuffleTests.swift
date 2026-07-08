//
//  SeededShuffleTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("SeededShuffle")
struct SeededShuffleTests {
    /// A fixed date (July 5, 2026, mid-day) so results are reproducible run to run.
    private var referenceDate: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12))!
    }

    private func day(offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: referenceDate)!
    }

    @Test func shuffledPositionsIsADeterministicDerangement() {
        let seed = DailyChallengeSeeder.seed(for: referenceDate)
        let first = SeededShuffle.shuffledPositions(count: 25, seed: seed)
        let second = SeededShuffle.shuffledPositions(count: 25, seed: seed)

        #expect(first == second)
        #expect(first.sorted() == Array(0..<25))
        // Derangement: no tile may start in its solved slot.
        #expect(!first.enumerated().contains { $0.offset == $0.element })
    }

    @Test func shuffledSlideBoardIsAValidNonIdentityPermutation() {
        for offset in 0..<10 {
            let seed = DailyChallengeSeeder.seed(for: day(offset: offset))
            let gridSize = 4
            let board = SeededShuffle.shuffledSlideBoard(count: gridSize * gridSize, gridSize: gridSize, seed: seed)
            #expect(board.sorted() == Array(0..<gridSize * gridSize))
            #expect(board != Array(0..<gridSize * gridSize))
        }
    }

    @Test func differentSeedsProduceDifferentShuffles() {
        // Proof the seed actually drives the result — needed for Challenge Friends, where
        // every challenge mints a fresh seed rather than deriving one from a calendar date.
        let a = SeededShuffle.shuffledPositions(count: 25, seed: 111)
        let b = SeededShuffle.shuffledPositions(count: 25, seed: 222)
        #expect(a != b)
    }
}
