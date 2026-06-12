//
//  SlideSolverTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/12/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("SlideSolver")
@MainActor
struct SlideSolverTests {
    private let solver = SlideSolver()
    private let slideEngine = SlideEngine()

    private func solvedTiles(gridSize: Int) -> [TileModel] {
        (0..<(gridSize * gridSize)).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
    }

    @Test func solveReturnsNoMovesForAlreadySolvedBoard() {
        let tiles = solvedTiles(gridSize: 3)
        #expect(solver.solve(tiles: tiles, gridSize: 3).isEmpty)
    }

    @Test(arguments: [3, 4, 5, 6, 7, 8])
    func solveReachesSolvedStateFromShuffledBoard(gridSize: Int) {
        let tiles = solvedTiles(gridSize: gridSize)
        for _ in 0..<20 {
            var shuffled = slideEngine.shuffle(tiles, gridSize: gridSize)
            let moves = solver.solve(tiles: shuffled, gridSize: gridSize)

            for move in moves {
                let didMove = slideEngine.areAdjacent(move, slideEngine.blankIndex(in: shuffled)!, gridSize: gridSize)
                #expect(didMove)
                slideEngine.slide(&shuffled, from: move, gridSize: gridSize)
            }

            #expect(slideEngine.isSolved(shuffled))
        }
    }
}
