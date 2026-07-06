//
//  DailyDayRecord.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import Foundation

/// The stats captured the first time a daily challenge is completed on a given
/// day — everything needed to rebuild that day's share card later. The day's
/// image, grid size, and game mode are not stored because they are derivable
/// from the date via `DailyChallengeSeeder`.
struct DailyDayRecord: Codable, Equatable {
    let moves: Int
    let time: TimeInterval
    /// The calendar streak as it stood right after that day's completion,
    /// shown as the flame badge on the rebuilt card.
    let streak: Int
}
