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
        /// The player's current win streak for this grid size / mode, or 0 when there's no
        /// active streak — also 0 in modes that don't track streaks (Zen, Time Trial, Daily,
        /// Limited Moves). The Lock Screen shows a flame badge only when this is above 0.
        var currentStreak: Int = 0
        /// The all-time best streak for this grid size / mode, or 0 when none exists yet.
        /// Rendered as a trophy badge alongside the flame when there's an ongoing streak.
        var bestStreak: Int = 0
        /// Fraction of tiles currently in their correct position, 0...1. Drives the Dynamic
        /// Island's compact/minimal progress ring — the at-a-glance "how close am I" cue.
        var progress: Double = 0
    }

    /// Display title of the mode being played (e.g. "Slide", "Daily Challenge").
    var gameModeTitle: String
    /// SF Symbol name representing the mode being played — a meaningful, at-a-glance cue
    /// (e.g. the Swap arrows, the Daily calendar) shown throughout the activity.
    var gameModeIcon: String
    /// Board dimension, for the "N × N" label.
    var gridSize: Int
}
