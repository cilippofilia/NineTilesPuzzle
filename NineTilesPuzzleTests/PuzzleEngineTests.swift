//
//  PuzzleEngineTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 5/25/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("PuzzleEngine")
@MainActor
struct PuzzleEngineTests {
    private let engine = PuzzleEngine()

    private func solvedTiles() -> [TileModel] {
        (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
    }

    // MARK: - shuffle

    @Test func shuffleIsNeverSolved() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            _ = engine.shuffle(tiles)
            #expect(!engine.isSolved(tiles))
        }
    }

    @Test func shuffleIsDerangement() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            _ = engine.shuffle(tiles)
            #expect(tiles.allSatisfy { $0.currentIndex != $0.id })
        }
    }

    @Test func shuffleProducesAllIndices() {
        let tiles = solvedTiles()
        _ = engine.shuffle(tiles)
        #expect(tiles.map { $0.currentIndex }.sorted() == Array(0..<9))
    }

    // MARK: - swap

    @Test func swapExchangesCurrentIndices() {
        var tiles = solvedTiles()
        engine.swap(&tiles, from: 0, to: 4)
        let tile0 = tiles.first { $0.id == 0 }!
        let tile4 = tiles.first { $0.id == 4 }!
        #expect(tile0.currentIndex == 4)
        #expect(tile4.currentIndex == 0)
    }

    @Test func swapLocksCorrectlyPlacedTile() {
        // tile id=2 starts at currentIndex=0; after swap(from:0, to:2) it lands on 2 → locked.
        var tiles = solvedTiles()
        tiles[0].currentIndex = 2
        tiles[2].currentIndex = 0
        engine.swap(&tiles, from: 0, to: 2)
        let tile2 = tiles.first { $0.id == 2 }!
        #expect(tile2.isLocked)
    }

    @Test func swapRejectsLockedSourceTile() {
        var tiles = solvedTiles()
        tiles[0].isLocked = true
        let snapshot = tiles.map { $0.currentIndex }
        engine.swap(&tiles, from: 0, to: 3)
        #expect(tiles.map { $0.currentIndex } == snapshot)
    }

    @Test func swapRejectsLockedTargetTile() {
        var tiles = solvedTiles()
        tiles[3].isLocked = true
        let snapshot = tiles.map { $0.currentIndex }
        engine.swap(&tiles, from: 0, to: 3)
        #expect(tiles.map { $0.currentIndex } == snapshot)
    }

    // MARK: - isSolved

    @Test func isSolvedReturnsTrueWhenAllLocked() {
        let tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: true) }
        #expect(engine.isSolved(tiles))
    }

    @Test func isSolvedReturnsFalseWhenAnyUnlocked() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: true) }
        tiles[4].isLocked = false
        #expect(!engine.isSolved(tiles))
    }
}
