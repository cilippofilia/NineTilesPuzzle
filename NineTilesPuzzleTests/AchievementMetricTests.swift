//
//  AchievementMetricTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/26/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("AchievementMetric")
@MainActor
struct AchievementMetricTests {
    private func makeStats() -> StatsStore {
        StatsStore(defaults: InMemoryPersistenceStore())
    }

    private func decode(_ raw: String) throws -> AchievementMetric {
        let json = "\"\(raw)\"".data(using: .utf8)!
        return try JSONDecoder().decode(AchievementMetric.self, from: json)
    }

    private func encode(_ metric: AchievementMetric) throws -> String {
        let data = try JSONEncoder().encode(metric)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Codable round-trip

    @Test func roundTripsEveryDottedStringCase() throws {
        let cases: [(String, AchievementMetric)] = [
            ("totalGamesPlayed", .totalGamesPlayed),
            ("gamesPlayedForSize.4", .gamesPlayedForSize(4)),
            ("gamesPlayedForMode.zen", .gamesPlayedForMode(.zen)),
            ("personalBestMoves.3.swap", .personalBestMoves(size: 3, mode: .swap)),
            ("timeTrialScore.3.timeTrial", .timeTrialScore(size: 3, mode: .timeTrial)),
            ("bestStreakOverall", .bestStreakOverall),
            ("distinctGridSizesCleared", .distinctGridSizesCleared),
            ("distinctGameModesPlayed", .distinctGameModesPlayed),
            ("zeroWasteSolve", .zeroWasteSolve),
            ("photoLibrarySolve", .photoLibrarySolve),
            ("quickSnapSolve", .quickSnapSolve),
            ("quickSnapSolveCount", .quickSnapSolveCount),
            ("numbersSolve", .numbersSolve),
            ("distinctMediaSourcesSolved", .distinctMediaSourcesSolved),
            ("comebackAfterBreak", .comebackAfterBreak),
            ("maxGamesInOneDay", .maxGamesInOneDay),
            ("bestLadderStageReached", .bestLadderStageReached),
            ("bestLadderScore", .bestLadderScore),
            ("challengesSent", .challengesSent),
            ("challengesWon", .challengesWon),
            ("challengesPlayed", .challengesPlayed),
            ("soloedInHourRange.0.5", .soloedInHourRange(start: 0, end: 5)),
            ("completionist", .completionist)
        ]

        for (raw, expected) in cases {
            #expect(try decode(raw) == expected)
            #expect(try encode(expected) == "\"\(raw)\"")
        }
    }

    @Test func decodingAnUnrecognizedOrMalformedStringThrows() {
        #expect(throws: DecodingError.self) { try decode("notARealMetric") }
        #expect(throws: DecodingError.self) { try decode("gamesPlayedForSize.notANumber") }
        #expect(throws: DecodingError.self) { try decode("personalBestMoves.3") }
    }

    // MARK: - value(in:justSolved:now:)

    @Test func totalGamesPlayedSumsAcrossEveryKey() {
        let stats = makeStats()
        stats.recordGamePlayed(for: StatsKey(gridSize: 3, gameMode: .swap))
        stats.recordGamePlayed(for: StatsKey(gridSize: 4, gameMode: .slide))
        #expect(AchievementMetric.totalGamesPlayed.value(in: stats, justSolved: false, now: .now) == 2)
    }

    @Test func gamesPlayedForModeSumsOnlyThatMode() {
        let stats = makeStats()
        stats.recordGamePlayed(for: StatsKey(gridSize: 3, gameMode: .zen))
        stats.recordGamePlayed(for: StatsKey(gridSize: 4, gameMode: .zen))
        stats.recordGamePlayed(for: StatsKey(gridSize: 3, gameMode: .swap))
        #expect(AchievementMetric.gamesPlayedForMode(.zen).value(in: stats, justSolved: false, now: .now) == 2)
    }

    @Test func personalBestMovesDefaultsToIntMaxWhenNeverRecorded() {
        let stats = makeStats()
        #expect(AchievementMetric.personalBestMoves(size: 3, mode: .swap).value(in: stats, justSolved: false, now: .now) == Int.max)

        stats.recordCompletion(for: StatsKey(gridSize: 3, gameMode: .swap), moves: 15, time: 10)
        #expect(AchievementMetric.personalBestMoves(size: 3, mode: .swap).value(in: stats, justSolved: false, now: .now) == 15)
    }

    @Test func bestStreakOverallTakesTheMaxAcrossKeys() {
        let stats = makeStats()
        stats.recordStreakIncrement(for: StatsKey(gridSize: 3, gameMode: .swap), trackRecord: true)
        for _ in 0..<5 { stats.recordStreakIncrement(for: StatsKey(gridSize: 4, gameMode: .slide), trackRecord: true) }
        #expect(AchievementMetric.bestStreakOverall.value(in: stats, justSolved: false, now: .now) == 5)
    }

    @Test func booleanFlagMetricsReportZeroOrOne() {
        let stats = makeStats()
        #expect(AchievementMetric.zeroWasteSolve.value(in: stats, justSolved: false, now: .now) == 0)
        stats.recordZeroWasteSolve()
        #expect(AchievementMetric.zeroWasteSolve.value(in: stats, justSolved: false, now: .now) == 1)

        #expect(AchievementMetric.photoLibrarySolve.value(in: stats, justSolved: false, now: .now) == 0)
        stats.recordPhotoLibrarySolve()
        #expect(AchievementMetric.photoLibrarySolve.value(in: stats, justSolved: false, now: .now) == 1)
    }

    @Test func quickSnapMetricsTrackFlagAndTally() {
        let stats = makeStats()
        #expect(AchievementMetric.quickSnapSolve.value(in: stats, justSolved: false, now: .now) == 0)
        #expect(AchievementMetric.quickSnapSolveCount.value(in: stats, justSolved: false, now: .now) == 0)

        stats.recordMediaSourceSolve(.camera)
        stats.recordMediaSourceSolve(.camera)
        #expect(AchievementMetric.quickSnapSolve.value(in: stats, justSolved: false, now: .now) == 1)
        #expect(AchievementMetric.quickSnapSolveCount.value(in: stats, justSolved: false, now: .now) == 2)
    }

    @Test func distinctMediaSourcesSolvedCountsEachSourceOnce() {
        let stats = makeStats()
        #expect(AchievementMetric.distinctMediaSourcesSolved.value(in: stats, justSolved: false, now: .now) == 0)

        stats.recordMediaSourceSolve(.random)
        stats.recordMediaSourceSolve(.random)
        stats.recordMediaSourceSolve(.local)
        stats.recordMediaSourceSolve(.mixed)
        stats.recordMediaSourceSolve(.numbers)
        stats.recordMediaSourceSolve(.camera)
        #expect(AchievementMetric.distinctMediaSourcesSolved.value(in: stats, justSolved: false, now: .now) == 5)
    }

    @Test func soloedInHourRangeOnlyCountsWhenJustSolvedAndInRange() {
        let stats = makeStats()
        let twoAM = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: .now)!
        let metric = AchievementMetric.soloedInHourRange(start: 0, end: 5)

        #expect(metric.value(in: stats, justSolved: false, now: twoAM) == 0)
        #expect(metric.value(in: stats, justSolved: true, now: twoAM) == 1)

        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!
        #expect(metric.value(in: stats, justSolved: true, now: noon) == 0)
    }

    @Test func completionistMetricAlwaysReportsZero() {
        let stats = makeStats()
        #expect(AchievementMetric.completionist.value(in: stats, justSolved: true, now: .now) == 0)
    }

    // MARK: - Challenge Friends metrics

    @Test func challengeMetricsDefaultToZeroWithoutAChallengeStore() {
        let stats = makeStats()
        #expect(AchievementMetric.challengesSent.value(in: stats, justSolved: false, now: .now) == 0)
        #expect(AchievementMetric.challengesWon.value(in: stats, justSolved: false, now: .now) == 0)
        #expect(AchievementMetric.challengesPlayed.value(in: stats, justSolved: false, now: .now) == 0)
    }

    @Test func challengeMetricsReadFromChallengeStore() {
        let stats = makeStats()
        let challenges = ChallengeStore(defaults: InMemoryPersistenceStore())
        let sent = FriendChallenge(
            senderName: "Me", gameMode: .swap, gridSize: 3, seed: 1,
            imageData: Data([0xFF, 0xD8, 0xFF]), senderMoves: 10, senderTime: 20
        )
        challenges.registerSent(sent, opponentLabel: "Alex", transport: .file)

        let won = FriendChallenge(
            senderName: "Alex", gameMode: .swap, gridSize: 3, seed: 2,
            imageData: Data([0xFF, 0xD8, 0xFF]), senderMoves: 30, senderTime: 20
        )
        challenges.registerReceived(won, transport: .file)
        challenges.recordCompletion(challengeID: won.id, moves: 10, time: 5)

        #expect(AchievementMetric.challengesSent.value(in: stats, challengeStore: challenges, justSolved: false, now: .now) == 1)
        #expect(AchievementMetric.challengesWon.value(in: stats, challengeStore: challenges, justSolved: false, now: .now) == 1)
        #expect(AchievementMetric.challengesPlayed.value(in: stats, challengeStore: challenges, justSolved: false, now: .now) == 1)
    }
}
