//
//  PuzzleEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import Foundation

@MainActor
struct PuzzleEngine {

    // MARK: - Shuffle

    /// Shuffles tiles into a random non-solved permutation, locking any that land in their correct slot.
    func shuffle(_ tiles: [TileModel]) -> [TileModel] {
        var indices = Array(0..<tiles.count)
        repeat {
            indices.shuffle()
        } while zip(tiles, indices).allSatisfy { tile, idx in tile.id == idx }

        zip(tiles, indices).forEach { tile, newIndex in
            tile.currentIndex = newIndex
            tile.isLocked = tile.id == newIndex
        }
        return tiles
    }

    // MARK: - Swap

    /// Swaps the tiles at the two given grid positions; no-ops if either tile is locked. Locks any tile that is now in its correct slot.
    func swap(_ tiles: inout [TileModel], from sourceIndex: Int, to targetIndex: Int) {
        guard
            let a = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let b = tiles.first(where: { $0.currentIndex == targetIndex }),
            !a.isLocked,
            !b.isLocked
        else { return }

        a.currentIndex = targetIndex
        b.currentIndex = sourceIndex

        tiles.forEach { tile in
            if tile.id == tile.currentIndex {
                tile.isLocked = true
            }
        }
    }

    // MARK: - Query

    /// Returns true when every tile is locked (i.e. in its correct position).
    func isSolved(_ tiles: [TileModel]) -> Bool {
        tiles.allSatisfy { $0.isLocked }
    }
}
