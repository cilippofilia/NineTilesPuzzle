//
//  CompletionComparison.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import Foundation

/// Builds the wide-layout side panel's rows: which stats a mode shows, live while playing
/// and, once solved, how each one stacks up against the personal bests captured just
/// before the solve was recorded. Mirrors `MenuStatsCardView`'s per-mode choice of what's
/// meaningful.
enum CompletionComparison {
    /// The current game's stats, as the session reports them.
    struct GameStats {
        var gameMode: GameMode
        var isLadderMode = false
        var isLadderRunComplete = false
        var moveCount = 0
        var elapsedTime: TimeInterval = 0
        /// The final Time Trial score once solved, the running estimate while playing.
        var timeTrialScore = 0
        var ladderRunScore = 0
        /// The stage just cleared (only read once solved).
        var ladderStage = 0
    }

    /// Rows for the game just solved, with any new bests moved to the top so the
    /// strongest result reads first. Pass `bests: nil` for games that aren't ranked
    /// (practice, Daily, Challenge); every row is then `.unranked`.
    static func rows(for stats: GameStats, bests: PersonalBestSnapshot?) -> [CompletionStatRow] {
        let rows: [CompletionStatRow]

        if stats.gameMode == .timeTrial && stats.isLadderMode {
            rows = [
                CompletionStatRow(
                    metric: .stage,
                    value: "\(stats.ladderStage) / \(GauntletLadderRules.stageCount)",
                    outcome: ladderOutcome(value: stats.ladderStage, best: bests?.ladderStage, isFinal: false) { "\($0)" }
                ),
                CompletionStatRow(
                    metric: .runScore,
                    value: stats.ladderRunScore.formattedScore,
                    outcome: ladderOutcome(
                        value: stats.ladderRunScore,
                        best: bests?.ladderRunScore,
                        isFinal: stats.isLadderRunComplete
                    ) { $0.formattedScore }
                )
            ]
        } else if stats.gameMode == .timeTrial {
            rows = [
                CompletionStatRow(
                    metric: .score,
                    value: stats.timeTrialScore.formattedScore,
                    outcome: rankedOutcome(
                        value: Double(stats.timeTrialScore),
                        best: bests.map { $0.score.map(Double.init) },
                        lowerIsBetter: false
                    ) { Int($0).formattedScore }
                ),
                movesRow(moveCount: stats.moveCount, bests: bests)
            ]
        } else {
            rows = [
                movesRow(moveCount: stats.moveCount, bests: bests),
                CompletionStatRow(
                    metric: .time,
                    value: stats.elapsedTime.formattedMinutesSeconds,
                    outcome: rankedOutcome(value: stats.elapsedTime, best: bests.map(\.time), lowerIsBetter: true) {
                        $0.formattedMinutesSeconds
                    }
                )
            ]
        }

        return rows.filter(\.isNewBest) + rows.filter { !$0.isNewBest }
    }

    /// Rows for a game still in progress: the live values, each beside the best it's
    /// chasing for reference. Nothing is compared yet — that waits for the solve.
    static func liveRows(for stats: GameStats, bests: PersonalBestSnapshot?) -> [CompletionStatRow] {
        if stats.gameMode == .timeTrial && stats.isLadderMode {
            let best = bests.map { $0.ladderRunScore > 0 ? $0.ladderRunScore.formattedScore : nil }
            return [
                CompletionStatRow(metric: .runScore, value: stats.ladderRunScore.formattedScore, outcome: referenceOutcome(best))
            ]
        }
        let movesRow = CompletionStatRow(
            metric: .moves,
            value: "\(stats.moveCount)",
            outcome: referenceOutcome(bests.map { $0.moves.map { "\($0)" } })
        )
        if stats.gameMode == .timeTrial {
            return [
                CompletionStatRow(
                    metric: .score,
                    value: stats.timeTrialScore.formattedScore,
                    outcome: referenceOutcome(bests.map { $0.score?.formattedScore })
                ),
                movesRow
            ]
        }
        return [
            movesRow,
            CompletionStatRow(
                metric: .time,
                value: stats.elapsedTime.formattedMinutesSeconds,
                outcome: referenceOutcome(bests.map { $0.time?.formattedMinutesSeconds })
            )
        ]
    }

    /// Doubly optional like `rankedOutcome`'s `best`: unranked game vs. no best recorded yet.
    private static func referenceOutcome(_ best: String??) -> CompletionStatRow.Outcome {
        guard let best, let best else { return .unranked }
        return .reference(best: best)
    }

    private static func movesRow(moveCount: Int, bests: PersonalBestSnapshot?) -> CompletionStatRow {
        CompletionStatRow(
            metric: .moves,
            value: "\(moveCount)",
            outcome: rankedOutcome(
                value: Double(moveCount),
                best: bests.map { $0.moves.map(Double.init) },
                lowerIsBetter: true
            ) { "\(Int($0))" }
        )
    }

    /// `best` is doubly optional: the outer level is whether the game is ranked at all,
    /// the inner whether a best has been recorded at this size yet.
    static func rankedOutcome(
        value: Double,
        best: Double??,
        lowerIsBetter: Bool,
        format: (Double) -> String
    ) -> CompletionStatRow.Outcome {
        guard let best else { return .unranked }
        guard let best else { return .newBest(previous: nil, delta: nil) }
        guard value != best else { return .tiedBest }

        let delta = (value > best ? "+" : "−") + format(abs(value - best))
        let isBetter = lowerIsBetter ? value < best : value > best
        if isBetter {
            return .newBest(previous: format(best), delta: delta)
        }

        let ratio = lowerIsBetter ? best / value : value / best
        return .missed(best: format(best), delta: delta, progress: min(max(ratio, 0), 1))
    }

    /// Gauntlet bests are all-time and only recorded at certain points: the furthest stage
    /// on every clear, the run score only once the whole run is complete. Mid-run, a run
    /// score below the record is shown for reference rather than as a miss — the run isn't
    /// over yet.
    private static func ladderOutcome(
        value: Int,
        best: Int?,
        isFinal: Bool,
        format: (Int) -> String
    ) -> CompletionStatRow.Outcome {
        guard let best else { return .unranked }
        guard best > 0 else { return .newBest(previous: nil, delta: nil) }
        if value > best {
            return .newBest(previous: format(best), delta: "+" + format(value - best))
        }
        if isFinal {
            return rankedOutcome(value: Double(value), best: Double(best), lowerIsBetter: false) { format(Int($0)) }
        }
        return .reference(best: format(best))
    }
}
