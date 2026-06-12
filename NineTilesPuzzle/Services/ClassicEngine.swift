//
//  ClassicEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

/// Classic mode: every tile is swappable; a tile that lands on its correct position
/// locks in place and can no longer be moved.
@MainActor
struct ClassicEngine: GameEngine {
    /// Shuffles tiles into a derangement — no tile lands on its correct position.
    func shuffle(_ tiles: [TileModel], gridSize: Int) -> [TileModel] {
        guard tiles.count > 1 else { return tiles }

        let shuffledTiles = tiles
        var indices = Array(0..<shuffledTiles.count)

        repeat {
            indices.shuffle()
        } while zip(shuffledTiles, indices).contains { tile, idx in tile.id == idx }

        for i in 0..<shuffledTiles.count {
            shuffledTiles[i].currentIndex = indices[i]
            shuffledTiles[i].isLocked = false
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
}
