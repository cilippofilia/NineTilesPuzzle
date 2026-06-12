//
//  SlideEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

/// Slide mode: one cell is always empty and tiles slide into it. A tile that lands on its
/// correct position stays draggable — `isLocked` is never set, so it can slide again later.
@MainActor
struct SlideEngine: GameEngine {
    /// Shuffles tiles into a random arrangement reachable from the solved state by legal slide
    /// moves, leaving the highest-numbered tile as the empty cell.
    ///
    /// Only half of all random permutations of a sliding puzzle are solvable: solvability
    /// depends on the parity of the permutation's inversions relative to the empty cell's row.
    /// If a random shuffle lands on an unsolvable permutation, swapping any two non-empty tiles
    /// flips that parity and restores solvability.
    func shuffle(_ tiles: [TileModel], gridSize: Int) -> [TileModel] {
        guard tiles.count > 1 else { return tiles }

        let shuffled = tiles
        let blankID = shuffled.count - 1
        let identity = Array(0..<shuffled.count)
        var indices: [Int]

        repeat {
            indices = identity.shuffled()
            if !isSolvable(indices, blankID: blankID, gridSize: gridSize) {
                let blankPosition = indices.firstIndex(of: blankID)!
                let others = (0..<indices.count).filter { $0 != blankPosition }
                indices.swapAt(others[0], others[1])
            }
        } while indices == identity

        for i in 0..<shuffled.count {
            shuffled[i].currentIndex = indices[i]
            shuffled[i].isLocked = false
        }

        return shuffled
    }

    /// Returns the empty cell's current grid index, identified as the tile with the highest id.
    func blankIndex(in tiles: [TileModel]) -> Int? {
        tiles.first(where: { $0.id == tiles.count - 1 })?.currentIndex
    }

    /// Returns true when the two grid indices are orthogonally adjacent (sharing an edge, not a corner).
    func areAdjacent(_ a: Int, _ b: Int, gridSize: Int) -> Bool {
        let rowDelta = abs(a / gridSize - b / gridSize)
        let colDelta = abs(a % gridSize - b % gridSize)
        return rowDelta + colDelta == 1
    }

    /// Slides the tile at `sourceIndex` into the empty cell; no-ops if they aren't adjacent.
    func slide(_ tiles: inout [TileModel], from sourceIndex: Int, gridSize: Int) {
        guard
            let blankOffset = tiles.firstIndex(where: { $0.id == tiles.count - 1 }),
            let sourceOffset = tiles.firstIndex(where: { $0.currentIndex == sourceIndex }),
            sourceOffset != blankOffset,
            areAdjacent(sourceIndex, tiles[blankOffset].currentIndex, gridSize: gridSize)
        else { return }

        let blankIndex = tiles[blankOffset].currentIndex
        tiles[blankOffset].currentIndex = sourceIndex
        tiles[sourceOffset].currentIndex = blankIndex
    }

    /// Standard 15-puzzle solvability check. `permutation[position]` is the tile id occupying
    /// that grid position. A board is solvable when the parity of inversions among the
    /// non-empty tiles matches the empty cell's row parity (counted from the bottom) on
    /// even-width boards, or is simply even on odd-width boards.
    func isSolvable(_ permutation: [Int], blankID: Int, gridSize: Int) -> Bool {
        let sequence = permutation.filter { $0 != blankID }
        var inversions = 0
        for i in 0..<sequence.count {
            for j in (i + 1)..<sequence.count where sequence[i] > sequence[j] {
                inversions += 1
            }
        }

        guard gridSize % 2 == 0 else { return inversions % 2 == 0 }

        let blankPosition = permutation.firstIndex(of: blankID)!
        let blankRowFromBottom = (gridSize - 1) - (blankPosition / gridSize)
        return (inversions + blankRowFromBottom) % 2 == 0
    }
}
