//
//  GameSessionGauntletLadderTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/20/26.
//

import Testing
@testable import NineTilesPuzzle

/// Covers `GameSession`'s Gauntlet Ladder integration: stage progression, cumulative
/// scoring with the win-streak term, the run-ending fail/complete states, and the
/// regression risk that a ladder stage clear must never write into the per-size `StatsKey`
/// Time Trial personal bests. Same `.numbers`-media + hand-built-board approach as
/// `GameSessionTimeTrialTests.swift` — synchronous, no network, no real sleeps.
@Suite("GameSession – Gauntlet Ladder")
@MainActor
struct GameSessionGauntletLadderTests {
    private func makeSession() async -> GameSession {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .timeTrial
        session.mediaSourceType = .numbers
        session.isLadderMode = true
        await session.startNewLadderRun()
        return session
    }

    /// Replaces the board with a fully-known layout: `idsAtIndex[i]` is the tile id
    /// occupying position `i`.
    private func setBoard(_ session: GameSession, idsAtIndex: [Int]) {
        session.tiles = idsAtIndex.enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
    }

    /// A board exactly one swap away from solved, sized to the session's current grid —
    /// generalizes the Time Trial suite's "swap 0/1 to solve in one move" trick to any
    /// stage's grid size.
    private func setOneMoveFromSolved(_ session: GameSession) {
        var ids = Array(0..<(session.gridSize * session.gridSize))
        ids.swapAt(0, 1)
        setBoard(session, idsAtIndex: ids)
    }

    /// Clears whatever stage is currently active in one move, then advances via the same
    /// `startNewGame()` call the "Continue" button uses — unless that clear just completed
    /// the run, in which case there's no next stage to start.
    private func clearCurrentStageAndContinue(_ session: GameSession) async {
        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1)
        if !session.isLadderRunComplete {
            await session.startNewGame()
        }
    }

    // MARK: - Starting a run

    @Test func startingALadderRunSetsStageOneAndItsBaseTimeLimit() async {
        let session = await makeSession()
        #expect(session.currentLadderStage == 1)
        #expect(session.gridSize == GauntletLadderRules.stage(1).gridSize)
        #expect(session.timeTrialRemaining == GauntletLadderRules.stage(1).baseTimeLimit)
        #expect(session.isTimeTrialRunning)
        #expect(!session.isLadderRunFailed)
        #expect(!session.isLadderRunComplete)
    }

    // MARK: - Clearing stages

    @Test func clearingAStageAdvancesToTheNextStageAndAccumulatesScore() async {
        let session = await makeSession()
        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.ladderCumulativeScore > 0)
        #expect(session.ladderWinStreak == 1)
        #expect(session.lastClearedLadderStage == 1)
        #expect(session.currentLadderStage == 2)
        let scoreAfterStage1 = session.ladderCumulativeScore

        await session.startNewGame() // the "Continue" path

        #expect(session.currentLadderStage == 2)
        #expect(session.gridSize == GauntletLadderRules.stage(2).gridSize)
        #expect(session.timeTrialRemaining == GauntletLadderRules.stage(2).baseTimeLimit)
        #expect(session.ladderCumulativeScore == scoreAfterStage1) // unchanged by Continue
    }

    @Test func cumulativeScoreSumsEachStagesContributionUsingTheCurrentWinStreak() async {
        let session = await makeSession()

        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1) // clears Stage 1 at streak 0
        let expectedStage1Score = GauntletLadderRules.stageScore(
            remainingSeconds: GauntletLadderRules.stage(1).baseTimeLimit,
            stage: GauntletLadderRules.stage(1),
            currentWinStreak: 0
        )
        #expect(session.ladderCumulativeScore == expectedStage1Score)

        await session.startNewGame()
        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1) // clears Stage 2 at streak 1
        let expectedStage2Score = GauntletLadderRules.stageScore(
            remainingSeconds: GauntletLadderRules.stage(2).baseTimeLimit,
            stage: GauntletLadderRules.stage(2),
            currentWinStreak: 1
        )

        #expect(session.ladderCumulativeScore == expectedStage1Score + expectedStage2Score)
        #expect(session.ladderWinStreak == 2)
    }

    @Test func clearingStageTenCompletesTheRunAndRecordsABest() async {
        let session = await makeSession()
        for _ in 1..<GauntletLadderRules.stageCount {
            await clearCurrentStageAndContinue(session)
        }
        #expect(session.currentLadderStage == GauntletLadderRules.stageCount)

        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1)

        #expect(session.isLadderRunComplete)
        #expect(!session.isLadderRunFailed)
        // Stays at 10 — clearing the final stage never advances past the table.
        #expect(session.currentLadderStage == GauntletLadderRules.stageCount)
        #expect(session.isNewLadderScoreRecord)
        #expect(session.bestLadderScoreOverall == session.ladderCumulativeScore)
        #expect(session.bestLadderStageReachedOverall == GauntletLadderRules.stageCount)
    }

    // MARK: - Failing a run

    @Test func runningOutOfTimeMidLadderFailsTheRunButPreservesPriorScore() async {
        let session = await makeSession()
        await clearCurrentStageAndContinue(session) // clear Stage 1, now on Stage 2
        let scoreAfterStage1 = session.ladderCumulativeScore
        #expect(scoreAfterStage1 > 0)

        // Stage 2 is also a 3×3 (50s limit, 2s penalty/move): a full derangement that
        // never locks a tile, repeated until the clock empties. ceil(50 / 2) = 25 moves.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        for _ in 0..<25 {
            session.swapTiles(from: 0, to: 1)
        }

        #expect(session.isTimeTrialFailed)
        #expect(session.isLadderRunFailed)
        #expect(!session.isLadderRunComplete)
        // Stage 1's contribution survives the failure — the fail overlay needs it.
        #expect(session.ladderCumulativeScore == scoreAfterStage1)
    }

    @Test func restartingAfterAFailedRunResetsToStageOne() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        for _ in 0..<30 { session.swapTiles(from: 0, to: 1) } // fail Stage 1 (60s / 2s)
        #expect(session.isLadderRunFailed)

        await session.startNewLadderRun()

        #expect(session.currentLadderStage == 1)
        #expect(session.ladderCumulativeScore == 0)
        #expect(session.ladderWinStreak == 0)
        #expect(!session.isLadderRunFailed)
        #expect(session.gridSize == GauntletLadderRules.stage(1).gridSize)
    }

    // MARK: - Persistence

    /// Verifies `saveToUserDefaults()` writes the four new ladder keys with the right
    /// values. A true write-then-reconstruct round-trip (as `StatsStoreTests` does) isn't
    /// practical here: restoring a second `GameSession` re-runs the existing "Numbers media
    /// is Slide-only" guard in `restoreFromUserDefaults()`, which resets `mediaSourceType`
    /// away from `.numbers` for a `.timeTrial` session — correct production behavior (that
    /// combination can never be reached via the real UI), but it trips the tile-restore
    /// guard chain for a session deliberately using `.numbers` to stay synchronous in tests.
    @Test func ladderProgressIsPersistedToUserDefaults() async {
        let defaults = InMemoryPersistenceStore()
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: defaults
        )
        session.selectedGameMode = .timeTrial
        session.mediaSourceType = .numbers
        session.isLadderMode = true
        await session.startNewLadderRun()
        setOneMoveFromSolved(session) // clears Stage 1, advances to Stage 2
        session.swapTiles(from: 0, to: 1)

        #expect(defaults.bool(forKey: GameSession.Keys.isLadderMode))
        #expect(defaults.integer(forKey: GameSession.Keys.currentLadderStage) == 2)
        #expect(defaults.integer(forKey: GameSession.Keys.ladderCumulativeScore) == session.ladderCumulativeScore)
        #expect(defaults.integer(forKey: GameSession.Keys.ladderWinStreak) == 1)
    }

    // MARK: - StatsKey isolation regression

    /// Protects the §2 "skip `recordCompletion`/`recordTimeTrialScore` in ladder mode"
    /// decision: a ladder stage clear must never write into the per-size single-puzzle
    /// Time Trial personal best for that grid size.
    @Test func ladderStageClearDoesNotPolluteSinglePuzzleTimeTrialPersonalBests() async {
        let session = await makeSession() // Stage 1 is a 3×3
        setOneMoveFromSolved(session)
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.personalBestScoreForCurrentSize == nil)
    }
}
