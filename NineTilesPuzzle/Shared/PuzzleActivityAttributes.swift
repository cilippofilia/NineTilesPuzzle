//
//  PuzzleActivityAttributes.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import ActivityKit
import Foundation

/// Describes the Live Activity for a puzzle that is still in progress, reminding the player —
/// on the Lock Screen and in the Dynamic Island — that a game is waiting to be finished.
///
/// Static fields (`gameModeTitle`, `gridSize`) are fixed for the life of a game. The dynamic
/// `ContentState` carries only the small values that change: the current board snapshot's
/// filename and the progress counters. The snapshot PNG itself is written to the shared App
/// Group container (see `LiveActivityStore`) and referenced by name, never embedded in the
/// state — the state is serialized on every update and must stay tiny.
///
/// Shared between the app and the widget extension: this file must be a member of both targets.
struct PuzzleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Filename (within the shared App Group container) of the current board snapshot PNG.
        /// A fresh name on every update busts the widget's image cache and sidesteps the race
        /// of the widget reading a file the app is simultaneously overwriting.
        var boardImageName: String
        /// Moves made so far this game.
        var moveCount: Int
        /// Elapsed solve time, frozen at the moment of each update. The puzzle clock pauses
        /// while the app is backgrounded, so a static value is consistent with the game itself.
        var elapsedTime: TimeInterval
    }

    /// Display title of the mode being played (e.g. "Slide", "Daily Challenge").
    var gameModeTitle: String
    /// SF Symbol name representing the mode being played — a meaningful, at-a-glance cue
    /// (e.g. the Swap arrows, the Daily calendar) shown throughout the activity.
    var gameModeIcon: String
    /// Board dimension, for the "N × N" label.
    var gridSize: Int
}
