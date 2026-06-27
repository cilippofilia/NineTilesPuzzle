//
//  WallOfFameSlot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import Foundation

/// Identifies one pinned-card slot on the Wall of Fame cork board.
/// Each slot corresponds to exactly one personal-record category.
enum WallOfFameSlot: Hashable {
    case bestMoves(gridSize: Int)
    case bestTime(gridSize: Int)
    case dailyBestMoves
    case dailyBestTime
    case calendarStreak

    static var allCases: [WallOfFameSlot] {
        (3...8).flatMap { [.bestMoves(gridSize: $0), .bestTime(gridSize: $0)] }
            + [.dailyBestMoves, .dailyBestTime, .calendarStreak]
    }

    /// Stable filename used to persist the card PNG to disk.
    var fileName: String {
        switch self {
        case .bestMoves(let size): "bestMoves_\(size)"
        case .bestTime(let size):  "bestTime_\(size)"
        case .dailyBestMoves:      "dailyBestMoves"
        case .dailyBestTime:       "dailyBestTime"
        case .calendarStreak:      "calendarStreak"
        }
    }

    var displayTitle: String {
        switch self {
        case .bestMoves(let size): "Fewest Moves · \(size)×\(size)"
        case .bestTime(let size):  "Fastest · \(size)×\(size)"
        case .dailyBestMoves:      "Daily Best Moves"
        case .dailyBestTime:       "Daily Best Time"
        case .calendarStreak:      "Calendar Streak"
        }
    }

    /// A stable integer derived from the slot identity, used to seed the card's pin angle.
    var seedValue: Int {
        switch self {
        case .bestMoves(let size): size
        case .bestTime(let size):  size + 100
        case .dailyBestMoves:      200
        case .dailyBestTime:       201
        case .calendarStreak:      202
        }
    }
}
