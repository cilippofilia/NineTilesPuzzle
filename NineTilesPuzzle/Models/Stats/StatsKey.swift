//
//  StatsKey.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

/// Grid size and move-mechanic differ enough per mode (e.g. Slide needs far more moves
/// than Swap to solve the same grid) that per-size stats must also be split by mode.
nonisolated struct StatsKey: Hashable {
    let gridSize: Int
    let gameMode: GameMode
}
