//
//  PuzzleEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
struct PuzzleEngine {
    /// Shuffles tiles into a random non-solved permutation, locking any that land in their correct slot.
    func shuffle(_ tiles: [TileModel]) -> [TileModel] {
        guard tiles.count > 1 else { return tiles }

        let shuffledTiles = tiles
        var indices = Array(0..<shuffledTiles.count)

        // Loop ensures the puzzle does NOT start in a fully solved state
        repeat {
            indices.shuffle()
        } while zip(shuffledTiles, indices).allSatisfy { tile, idx in tile.id == idx }

        // Mutate the value types cleanly over the indices
        for i in 0..<shuffledTiles.count {
            let newIndex = indices[i]
            shuffledTiles[i].currentIndex = newIndex
            shuffledTiles[i].isLocked = (shuffledTiles[i].id == newIndex)
        }

        return shuffledTiles
    }

    /// Swaps the tiles at the two given grid positions; no-ops if either tile is locked. Locks any tile that is now in its correct slot.
    func swap(_ tiles: inout [TileModel], from sourceIndex: Int, to targetIndex: Int) {
        // 1. Find the array offsets of the matching tile positions in a single pass
        guard
            let sourceOffset = tiles.firstIndex(where: { $0.currentIndex == sourceIndex }),
            let targetOffset = tiles.firstIndex(where: { $0.currentIndex == targetIndex })
        else { return }

        // 2. Guard against swapping locked tiles
        guard !tiles[sourceOffset].isLocked, !tiles[targetOffset].isLocked else { return }

        // 3. Perform the value-type swap directly in the array
        tiles[sourceOffset].currentIndex = targetIndex
        tiles[targetOffset].currentIndex = sourceIndex

        // 4. Update the lock status inline for only the modified tiles (O(1) optimization)
        if tiles[sourceOffset].id == tiles[sourceOffset].currentIndex {
            tiles[sourceOffset].isLocked = true
        }
        if tiles[targetOffset].id == tiles[targetOffset].currentIndex {
            tiles[targetOffset].isLocked = true
        }
    }

    /// Returns true when every tile is locked in its correct position.
    func isSolved(_ tiles: [TileModel]) -> Bool {
        tiles.allSatisfy { $0.isLocked }
    }
}
