//
//  PuzzleEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import Foundation

struct PuzzleEngine {
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

    func swap(_ tiles: inout [TileModel], from sourceIndex: Int, to targetIndex: Int) {
        guard
            let a = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let b = tiles.first(where: { $0.currentIndex == targetIndex })
        else { return }

        a.currentIndex = targetIndex
        b.currentIndex = sourceIndex

        tiles.forEach { tile in
            if tile.id == tile.currentIndex {
                tile.isLocked = true
            }
        }
    }

    func isSolved(_ tiles: [TileModel]) -> Bool {
        tiles.allSatisfy { $0.isLocked }
    }
}
