//
//  GameEngine.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

/// Shared rules for a puzzle game mode: how a fresh board is shuffled and how a solved
/// board is recognized. Mode-specific moves (e.g. swapping tiles vs. sliding into an
/// empty cell) live on the conforming types, since their signatures differ per mode.
@MainActor
protocol GameEngine {
    /// Produces a shuffled, playable arrangement of tiles for a fresh game.
    func shuffle(_ tiles: [TileModel], gridSize: Int) -> [TileModel]
}

extension GameEngine {
    /// Returns true once every tile occupies its target position.
    func isSolved(_ tiles: [TileModel]) -> Bool {
        tiles.allSatisfy { $0.isCorrect }
    }
}
