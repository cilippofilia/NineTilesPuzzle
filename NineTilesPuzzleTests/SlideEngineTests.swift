//
//  SlideEngineTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/12/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("SlideEngine")
@MainActor
struct SlideEngineTests {
    private let engine = SlideEngine()

    private func solvedTiles() -> [TileModel] {
        (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
    }

    // MARK: - areAdjacent

    @Test func areAdjacentRecognizesOrthogonalNeighbors() {
        #expect(engine.areAdjacent(0, 1, gridSize: 3))
        #expect(engine.areAdjacent(0, 3, gridSize: 3))
        #expect(engine.areAdjacent(4, 1, gridSize: 3))
        #expect(engine.areAdjacent(4, 7, gridSize: 3))
    }

    @Test func areAdjacentRejectsDiagonalsAndRowWrap() {
        #expect(!engine.areAdjacent(0, 4, gridSize: 3)) // diagonal
        #expect(!engine.areAdjacent(2, 3, gridSize: 3)) // wraps from end of row 0 to start of row 1
        #expect(!engine.areAdjacent(4, 4, gridSize: 3)) // same cell
    }

    // MARK: - blankIndex

    @Test func blankIndexReturnsPositionOfHighestIDTile() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        tiles[8].currentIndex = 3
        #expect(engine.blankIndex(in: tiles) == 3)
    }

    // MARK: - slide

    @Test func slideMovesAdjacentTileIntoBlank() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        tiles[8].currentIndex = 4 // blank in the center
        engine.slide(&tiles, from: 1, gridSize: 3) // tile 1 sits above the blank

        let blank = tiles.first { $0.id == 8 }!
        let moved = tiles.first { $0.id == 1 }!
        #expect(blank.currentIndex == 1)
        #expect(moved.currentIndex == 4)
    }

    @Test func slideNoOpsWhenNotAdjacent() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        tiles[8].currentIndex = 4 // blank in the center
        let snapshot = tiles.map { $0.currentIndex }
        engine.slide(&tiles, from: 0, gridSize: 3) // corner, not adjacent to center
        #expect(tiles.map { $0.currentIndex } == snapshot)
    }

    @Test func slideNoOpsWhenSourceIsBlank() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        tiles[8].currentIndex = 4 // blank in the center
        let snapshot = tiles.map { $0.currentIndex }
        engine.slide(&tiles, from: 4, gridSize: 3)
        #expect(tiles.map { $0.currentIndex } == snapshot)
    }

    @Test func slideNeverLocksTilesEvenWhenCorrectlyPlaced() {
        var tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        // Place blank (id 8) at index 1, tile 1 at index 8; sliding tile 1 into the blank
        // moves it to index 1, its correct position.
        tiles[8].currentIndex = 1
        tiles[1].currentIndex = 8
        engine.slide(&tiles, from: 8, gridSize: 3)

        let movedTile = tiles.first { $0.id == 1 }!
        let blankTile = tiles.first { $0.id == 8 }!
        #expect(movedTile.currentIndex == 1)
        #expect(movedTile.isCorrect)
        #expect(!movedTile.isLocked)
        #expect(blankTile.currentIndex == 8)
        #expect(!blankTile.isLocked)
    }

    // MARK: - isSolvable

    @Test func isSolvableReturnsTrueForIdentity() {
        let identity = Array(0..<9)
        #expect(engine.isSolvable(identity, blankID: 8, gridSize: 3))
    }

    @Test func isSolvableReturnsFalseForSingleTranspositionOnOddGrid() {
        // A single adjacent swap from the goal state is the classic unsolvable case.
        var permutation = Array(0..<9)
        permutation.swapAt(0, 1)
        #expect(!engine.isSolvable(permutation, blankID: 8, gridSize: 3))
    }

    @Test func isSolvableAccountsForBlankRowOnEvenGrids() {
        let blankID = 15
        var permutation = Array(0..<16)
        // Single transposition: odd permutation parity (1 inversion).
        permutation.swapAt(0, 1)
        // Blank stays in the goal corner (row 3, bottom row → blankRowFromBottom == 0).
        #expect(!engine.isSolvable(permutation, blankID: blankID, gridSize: 4))
    }

    // MARK: - shuffle

    @Test func shuffleProducesAPermutation() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            #expect(shuffled.map(\.currentIndex).sorted() == Array(0..<9))
        }
    }

    @Test func shuffleNeverReturnsTheSolvedState() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            #expect(!engine.isSolved(shuffled))
        }
    }

    @Test func shuffleNeverLocksAnyTile() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            #expect(shuffled.allSatisfy { !$0.isLocked })
        }
    }

    @Test func shuffleAlwaysProducesASolvableArrangement() {
        let tiles = solvedTiles()
        for _ in 0..<200 {
            let shuffled = engine.shuffle(tiles, gridSize: 3)
            let permutation = (0..<9).map { position in
                shuffled.first { $0.currentIndex == position }!.id
            }
            #expect(engine.isSolvable(permutation, blankID: 8, gridSize: 3))
        }
    }

    @Test func shuffleWorksOnEvenSizedGrids() {
        let tiles = (0..<16).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        for _ in 0..<100 {
            let shuffled = engine.shuffle(tiles, gridSize: 4)
            #expect(shuffled.map(\.currentIndex).sorted() == Array(0..<16))
            let permutation = (0..<16).map { position in
                shuffled.first { $0.currentIndex == position }!.id
            }
            #expect(engine.isSolvable(permutation, blankID: 15, gridSize: 4))
        }
    }

    /// Sanity check for the puzzle's well-known parity theorem: roughly half of all random
    /// permutations of a sliding puzzle are solvable.
    @Test func aboutHalfOfRandomPermutationsAreSolvable() {
        let trials = 4000
        var solvableCount = 0
        for _ in 0..<trials {
            let permutation = Array(0..<9).shuffled()
            if engine.isSolvable(permutation, blankID: 8, gridSize: 3) {
                solvableCount += 1
            }
        }
        let ratio = Double(solvableCount) / Double(trials)
        #expect(ratio > 0.4 && ratio < 0.6)
    }
}
