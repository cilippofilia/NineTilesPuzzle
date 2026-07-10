//
//  AchievementMetric.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import Foundation

/// What an achievement's `target` is measured against. Encoded as a single dotted string
/// (e.g. "personalBestMoves.3.swap") rather than relying on Swift's auto-synthesized
/// enum-with-associated-values `Codable`, which would produce a nested-keyed JSON shape
/// that's awkward to hand-edit in `achievements.json`.
enum AchievementMetric: Equatable {
    case totalGamesPlayed
    case gamesPlayedForSize(Int)
    case gamesPlayedForMode(GameMode)
    case personalBestMoves(size: Int, mode: GameMode)
    case timeTrialScore(size: Int, mode: GameMode)
    case bestStreakOverall
    case distinctGridSizesCleared
    case distinctGameModesPlayed
    case zeroWasteSolve
    case photoLibrarySolve
    case quickSnapSolve
    case quickSnapSolveCount
    case numbersSolve
    case distinctMediaSourcesSolved
    case comebackAfterBreak
    case maxGamesInOneDay
    case bestLadderStageReached
    case bestLadderScore
    case challengesSent
    case challengesWon
    case challengesPlayed
    /// True only on the exact `checkAchievements` call that just solved a puzzle, and only
    /// if the wall-clock hour falls in `start..<end` — the one metric pair that reads "now"
    /// instead of `StatsStore`.
    case soloedInHourRange(start: Int, end: Int)
    /// Always reports 0 — `AchievementsStore` special-cases the Completionist achievement
    /// itself, since "every other achievement is unlocked" depends on the achievements list,
    /// not on `StatsStore`. This case exists purely so the JSON entry still has a documented,
    /// type-checked metric string instead of borrowing an unrelated one.
    case completionist

    /// Current value of this metric, compared against an achievement's `target`.
    /// `challengeStore` is optional — only the three Challenge Friends metrics read it,
    /// so existing call sites that don't have one on hand can omit it.
    func value(in stats: StatsStore, challengeStore: ChallengeStore? = nil, justSolved: Bool, now: Date) -> Int {
        switch self {
        case .totalGamesPlayed:
            return stats.gamesPlayed.values.reduce(0, +)
        case .gamesPlayedForSize(let size):
            return stats.gamesPlayedCount(forSize: size)
        case .gamesPlayedForMode(let mode):
            return stats.gamesPlayed.filter { $0.key.gameMode == mode }.values.reduce(0, +)
        case .personalBestMoves(let size, let mode):
            return stats.personalBestMoves[StatsKey(gridSize: size, gameMode: mode)] ?? Int.max
        case .timeTrialScore(let size, let mode):
            return stats.personalBestScore[StatsKey(gridSize: size, gameMode: mode)] ?? 0
        case .bestStreakOverall:
            return stats.allTimeHighStreak.values.max() ?? 0
        case .distinctGridSizesCleared:
            return stats.distinctGridSizesCleared
        case .distinctGameModesPlayed:
            return stats.distinctGameModesPlayed
        case .zeroWasteSolve:
            return stats.hasZeroWasteSolve ? 1 : 0
        case .photoLibrarySolve:
            return stats.hasSolvedWithPhotoLibrary ? 1 : 0
        case .quickSnapSolve:
            return stats.hasSolvedWithQuickSnap ? 1 : 0
        case .quickSnapSolveCount:
            return stats.quickSnapSolveCount
        case .numbersSolve:
            return stats.hasSolvedWithNumbers ? 1 : 0
        case .distinctMediaSourcesSolved:
            return stats.distinctMediaSourcesSolved
        case .comebackAfterBreak:
            return stats.hasComebackAfterBreak ? 1 : 0
        case .maxGamesInOneDay:
            return stats.maxGamesInOneDay
        case .bestLadderStageReached:
            return stats.bestLadderStageReached
        case .bestLadderScore:
            return stats.bestLadderScore
        case .challengesSent:
            return challengeStore?.count(direction: .sent) ?? 0
        case .challengesWon:
            return challengeStore?.count(outcome: .won) ?? 0
        case .challengesPlayed:
            return challengeStore?.playedReceivedCount ?? 0
        case .soloedInHourRange(let start, let end):
            guard justSolved else { return 0 }
            let hour = Calendar.current.component(.hour, from: now)
            return (start..<end).contains(hour) ? 1 : 0
        case .completionist:
            return 0
        }
    }
}

extension AchievementMetric: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let parts = raw.split(separator: ".").map(String.init)

        func size(_ index: Int) -> Int? { parts.count > index ? Int(parts[index]) : nil }
        func mode(_ index: Int) -> GameMode? { parts.count > index ? GameMode(rawValue: parts[index]) : nil }

        switch parts.first {
        case "totalGamesPlayed":
            self = .totalGamesPlayed
        case "gamesPlayedForSize":
            guard parts.count == 2, let size = size(1) else { throw Self.malformed(raw) }
            self = .gamesPlayedForSize(size)
        case "gamesPlayedForMode":
            guard parts.count == 2, let mode = mode(1) else { throw Self.malformed(raw) }
            self = .gamesPlayedForMode(mode)
        case "personalBestMoves":
            guard parts.count == 3, let size = size(1), let mode = mode(2) else { throw Self.malformed(raw) }
            self = .personalBestMoves(size: size, mode: mode)
        case "timeTrialScore":
            guard parts.count == 3, let size = size(1), let mode = mode(2) else { throw Self.malformed(raw) }
            self = .timeTrialScore(size: size, mode: mode)
        case "bestStreakOverall":
            self = .bestStreakOverall
        case "distinctGridSizesCleared":
            self = .distinctGridSizesCleared
        case "distinctGameModesPlayed":
            self = .distinctGameModesPlayed
        case "zeroWasteSolve":
            self = .zeroWasteSolve
        case "photoLibrarySolve":
            self = .photoLibrarySolve
        case "quickSnapSolve":
            self = .quickSnapSolve
        case "quickSnapSolveCount":
            self = .quickSnapSolveCount
        case "numbersSolve":
            self = .numbersSolve
        case "distinctMediaSourcesSolved":
            self = .distinctMediaSourcesSolved
        case "comebackAfterBreak":
            self = .comebackAfterBreak
        case "maxGamesInOneDay":
            self = .maxGamesInOneDay
        case "bestLadderStageReached":
            self = .bestLadderStageReached
        case "bestLadderScore":
            self = .bestLadderScore
        case "challengesSent":
            self = .challengesSent
        case "challengesWon":
            self = .challengesWon
        case "challengesPlayed":
            self = .challengesPlayed
        case "soloedInHourRange":
            guard parts.count == 3, let start = size(1), let end = size(2) else { throw Self.malformed(raw) }
            self = .soloedInHourRange(start: start, end: end)
        case "completionist":
            self = .completionist
        default:
            throw Self.malformed(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encodedString)
    }

    private var encodedString: String {
        switch self {
        case .totalGamesPlayed: "totalGamesPlayed"
        case .gamesPlayedForSize(let size): "gamesPlayedForSize.\(size)"
        case .gamesPlayedForMode(let mode): "gamesPlayedForMode.\(mode.rawValue)"
        case .personalBestMoves(let size, let mode): "personalBestMoves.\(size).\(mode.rawValue)"
        case .timeTrialScore(let size, let mode): "timeTrialScore.\(size).\(mode.rawValue)"
        case .bestStreakOverall: "bestStreakOverall"
        case .distinctGridSizesCleared: "distinctGridSizesCleared"
        case .distinctGameModesPlayed: "distinctGameModesPlayed"
        case .zeroWasteSolve: "zeroWasteSolve"
        case .photoLibrarySolve: "photoLibrarySolve"
        case .quickSnapSolve: "quickSnapSolve"
        case .quickSnapSolveCount: "quickSnapSolveCount"
        case .numbersSolve: "numbersSolve"
        case .distinctMediaSourcesSolved: "distinctMediaSourcesSolved"
        case .comebackAfterBreak: "comebackAfterBreak"
        case .maxGamesInOneDay: "maxGamesInOneDay"
        case .bestLadderStageReached: "bestLadderStageReached"
        case .bestLadderScore: "bestLadderScore"
        case .challengesSent: "challengesSent"
        case .challengesWon: "challengesWon"
        case .challengesPlayed: "challengesPlayed"
        case .soloedInHourRange(let start, let end): "soloedInHourRange.\(start).\(end)"
        case .completionist: "completionist"
        }
    }

    private static func malformed(_ raw: String) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [],
            debugDescription: "Unrecognized AchievementMetric string: \(raw)"
        ))
    }
}
