//
//  PuzzleRecordFlags.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import Foundation

/// A snapshot of every "new record" flag a solve can set, bundled so `PuzzleView` can react
/// to all of them with a single `.onChange` instead of one per flag. Being `Equatable` lets
/// SwiftUI detect when any record state changes between renders.
struct PuzzleRecordFlags: Equatable {
    var isNewRecord = false
    var isNewMovesRecord = false
    var isNewBestTime = false
    var isNewTimeTrialScoreRecord = false
    var isNewLadderScoreRecord = false
    var isNewLadderStageRecord = false
}
