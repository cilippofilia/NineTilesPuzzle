//
//  SwapEngineTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/12/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("SwapEngine")
@MainActor
struct SwapEngineTests {
    private let engine = SwapEngine()

    private func solvedTiles() -> [TileModel] {
        (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
    }

    // MARK: - shuffle

    @Test func shuffleIsNeverSolved() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            #expect(!engine.isSolved(shuffled))
        }
    }

    @Test func shuffleIsDerangement() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            #expect(shuffled.allSatisfy { $0.currentIndex != $0.id })
        }
    }

    @Test func shuffleProducesAllIndices() {
        let tiles = solvedTiles()
        let shuffled = engine.shuffle(tiles, gridSize: 3)
        #expect(shuffled.map { $0.currentIndex }.sorted() == Array(0..<9))
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

    // MARK: - reshuffleUnlocked

    @Test func reshuffleUnlockedNeverReproducesTheExactSameArrangement() {
        for _ in 0..<200 {
            var tiles = solvedTiles()
            tiles[0].currentIndex = 3
            tiles[3].currentIndex = 0
            let before = tiles.map(\.currentIndex)
            engine.reshuffleUnlocked(&tiles)
            #expect(tiles.map(\.currentIndex) != before)
        }
    }

    @Test func reshuffleUnlockedLeavesLockedTilesUntouched() {
        var tiles = solvedTiles()
        tiles[0].currentIndex = 3
        tiles[3].currentIndex = 0
        tiles[6].isLocked = true // sits at its own correct index, id == currentIndex == 6
        engine.reshuffleUnlocked(&tiles)
        let tile6 = tiles.first { $0.id == 6 }!
        #expect(tile6.currentIndex == 6)
        #expect(tile6.isLocked)
    }

    @Test func reshuffleUnlockedOnlyPermutesAmongTheOriginallyUnlockedPositions() {
        var tiles = solvedTiles()
        tiles[0].currentIndex = 3
        tiles[3].currentIndex = 0
        tiles[6].isLocked = true
        let originallyUnlockedPositions = tiles.filter { !$0.isLocked }.map(\.currentIndex).sorted()
        engine.reshuffleUnlocked(&tiles)
        // Identify the same tiles by id (lock state may have changed) and confirm they
        // still occupy exactly the same set of positions, just reassigned among themselves.
        let sameTilesPositionsAfter = tiles.filter { $0.id != 6 }.map(\.currentIndex).sorted()
        #expect(sameTilesPositionsAfter == originallyUnlockedPositions)
    }

    @Test func reshuffleUnlockedNoOpsWithOneOrFewerUnlockedTiles() {
        var tiles = solvedTiles()
        for i in tiles.indices where i != 0 { tiles[i].isLocked = true }
        let before = tiles.map(\.currentIndex)
        engine.reshuffleUnlocked(&tiles)
        #expect(tiles.map(\.currentIndex) == before)
    }

    @Test func reshuffleUnlockedCanLandATileCorrectlyAndLockIt() {
        // Run many trials since landing correctly is only one of several random outcomes.
        var everLockedSomething = false
        for _ in 0..<500 {
            var tiles = solvedTiles()
            tiles[0].currentIndex = 3
            tiles[3].currentIndex = 0
            engine.reshuffleUnlocked(&tiles)
            if tiles.contains(where: { $0.isLocked }) {
                everLockedSomething = true
                break
            }
        }
        #expect(everLockedSomething)
    }

    // MARK: - isSolved

    @Test func isSolvedReturnsTrueWhenAllTilesAreInPosition() {
        let tiles = solvedTiles()
        #expect(engine.isSolved(tiles))
    }

    @Test func isSolvedReturnsFalseWhenATileIsOutOfPosition() {
        let tiles = solvedTiles()
        tiles[4].currentIndex = 5
        tiles[5].currentIndex = 4
        #expect(!engine.isSolved(tiles))
    }
}
