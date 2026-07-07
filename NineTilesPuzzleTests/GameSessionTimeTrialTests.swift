//
//  GameSessionTimeTrialTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/20/26.
//

import Testing
@testable import NineTilesPuzzle

/// Covers `GameSession`'s Time Trial integration (Step 2 of the feature): the countdown
/// lifecycle, combo bonus/misplay penalty, fail state, and score recording on solve.
///
/// Uses `.numbers` media mode so `startNewGame()` completes synchronously with no network
/// or image work, and replaces the shuffled board with hand-built layouts (mirroring
/// `SwapEngineTests`) so moves can be engineered deterministically rather than depending
/// on the shuffle's randomness. Because these tests never `await` a real sleep, the
/// countdown's background tick task never gets scheduled mid-test — only the synchronous
/// `applyTimeTrialMoveOutcome` logic under test ever touches the timer state.
@Suite("GameSession – Time Trial")
@MainActor
struct GameSessionTimeTrialTests {
    private func makeSession(gridSize: Int = 3) async -> GameSession {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            powerUpStore: PowerUpStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .timeTrial
        session.mediaSourceType = .numbers
        session.gridSize = gridSize
        await session.startNewGame()
        return session
    }

    /// Replaces the board with a fully-known layout: `idsAtIndex[i]` is the tile id
    /// occupying position `i`.
    private func setBoard(_ session: GameSession, idsAtIndex: [Int]) {
        session.tiles = idsAtIndex.enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
    }

    // MARK: - Starting a game

    @Test func startingAGameSetsTheBaseTimeLimitAndStartsRunning() async {
        let session = await makeSession(gridSize: 5)
        #expect(session.isTimeTrialRunning)
        #expect(!session.isTimeTrialFailed)
        #expect(session.timeTrialRemaining == TimeTrialRules.baseTimeLimit(forGridSize: 5))
    }

    // MARK: - Combo bonus / misplay penalty

    @Test func correctlyPlacedTileAppliesComboBonusAndLocksTheTile() async {
        let session = await makeSession()
        // Indices 7/8 stay wrong so this move alone can't accidentally solve the puzzle.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        let before = session.timeTrialRemaining

        session.swapTiles(from: 0, to: 1)

        #expect(session.lastTimeTrialDelta == TimeTrialRules.comboBonusSeconds)
        #expect(session.timeTrialRemaining > before)
        #expect(!session.isTimeTrialFailed)
        #expect(session.tiles.first { $0.id == 0 }?.isLocked == true)
        #expect(session.tiles.first { $0.id == 1 }?.isLocked == true)
    }

    @Test func misplacedMoveAppliesMisplayPenaltyAndLocksNothing() async {
        let session = await makeSession()
        // A full derangement: swapping 0/1 never lands either tile on its own id.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        let before = session.timeTrialRemaining

        session.swapTiles(from: 0, to: 1)

        #expect(session.lastTimeTrialDelta == -TimeTrialRules.misplayPenaltySeconds)
        #expect(session.timeTrialRemaining < before)
        #expect(session.tiles.allSatisfy { !$0.isLocked })
    }

    // MARK: - Fail state

    @Test func runningOutOfTimeFailsAndLocksTheGrid() async {
        let session = await makeSession() // 3×3 → 35s base limit, 2s penalty per move.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])

        // ceil(35 / 2) = 18 penalty moves drains the clock to zero.
        for _ in 0..<18 {
            session.swapTiles(from: 0, to: 1)
        }

        #expect(session.isTimeTrialFailed)
        #expect(session.timeTrialRemaining == 0)
        #expect(!session.isTimeTrialRunning)

        // The grid stops responding once failed.
        let snapshot = session.tiles.map(\.currentIndex)
        session.swapTiles(from: 0, to: 1)
        #expect(session.tiles.map(\.currentIndex) == snapshot)
    }

    // MARK: - Solving

    @Test func solvingRecordsANewScoreAndStopsTheCountdown() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])

        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(!session.isTimeTrialRunning)
        #expect(session.isNewTimeTrialScoreRecord)
        // Solving doesn't also apply a bonus/penalty to the score-affecting remaining time
        // (see `applyTimeTrialMoveOutcome`'s `guard !isSolved`), so the score reflects the
        // full base limit (no other moves preceded this one): 35 * 100 * (3 / 3) = 3500.
        #expect(session.timeTrialScore == 3500)
    }

    @Test func secondLowerScoreIsNotANewRecord() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])
        session.swapTiles(from: 0, to: 1)
        #expect(session.isNewTimeTrialScoreRecord)

        await session.startNewGame()
        // A misplay first, so the eventual solve scores lower than the first run's 3500.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 2, 1, 3, 4])
        session.swapTiles(from: 0, to: 1)
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(!session.isNewTimeTrialScoreRecord)
    }
}
