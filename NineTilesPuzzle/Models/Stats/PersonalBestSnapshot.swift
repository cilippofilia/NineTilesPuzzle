//
//  PersonalBestSnapshot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import Foundation

/// The personal bests for the game being played, captured the instant it's solved but
/// *before* the solve is recorded. Recording a new best overwrites the old one in
/// `StatsStore`, so this is the only way completion UI can still compare the solve against
/// what the player was actually trying to beat (e.g. "1:38 — was 1:52").
nonisolated struct PersonalBestSnapshot: Equatable {
    var moves: Int?
    var time: TimeInterval?
    var score: Int?
    /// Gauntlet Ladder bests are all-time, not per size — `0` means no run recorded yet.
    var ladderRunScore: Int = 0
    var ladderStage: Int = 0
}
