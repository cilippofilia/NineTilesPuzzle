//
//  CompletionStatRow.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import Foundation

/// One row of the wide-layout completion panel: a single stat from the game just solved,
/// and how it compares to the player's personal best for the same mode and grid size.
/// Built by `CompletionComparison`; every display string is resolved here so the row view
/// stays purely presentational.
struct CompletionStatRow: Identifiable, Equatable {
    enum Metric: Equatable {
        case moves, time, score, runScore, stage

        var title: String {
            switch self {
            case .moves: "Moves"
            case .time: "Time"
            case .score: "Score"
            case .runScore: "Run Score"
            case .stage: "Stage"
            }
        }

        var icon: String {
            switch self {
            case .moves: "arrow.left.arrow.right"
            case .time: "clock"
            case .score: "bolt.fill"
            case .runScore: "star.fill"
            case .stage: "figure.stairs"
            }
        }
    }

    enum Outcome: Equatable {
        /// Beat the best. `previous` is nil when there was no best to beat yet.
        case newBest(previous: String?, delta: String?)
        case tiedBest
        /// Fell short. `progress` (0...1) is how close the solve came to the best.
        case missed(best: String, delta: String, progress: Double)
        /// A best exists but comparing against it isn't meaningful yet (a Gauntlet run
        /// still in progress), so it's shown for reference only.
        case reference(best: String)
        /// Not ranked at all — practice play, Daily, and Challenge games have no
        /// per-size personal best to compare against.
        case unranked
    }

    let metric: Metric
    let value: String
    let outcome: Outcome

    var id: Metric { metric }

    var isNewBest: Bool {
        if case .newBest = outcome { return true }
        return false
    }

    /// The secondary text beside the value.
    var caption: String? {
        switch outcome {
        case .newBest(let previous?, _): "was \(previous)"
        case .newBest(nil, _): "First record"
        case .tiedBest: "Matched your best"
        case .missed(let best, _, _), .reference(let best): "best \(best)"
        case .unranked: nil
        }
    }

    /// The signed difference from the best, e.g. "−0:14" or "+23".
    var delta: String? {
        switch outcome {
        case .newBest(_, let delta): delta
        case .missed(_, let delta, _): delta
        case .tiedBest, .reference, .unranked: nil
        }
    }

    /// How full the comparison bar is, or nil when the row shows no bar.
    var progress: Double? {
        switch outcome {
        case .newBest, .tiedBest: 1
        case .missed(_, _, let progress): progress
        case .reference, .unranked: nil
        }
    }
}
