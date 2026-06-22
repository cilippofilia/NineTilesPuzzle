//
//  GameSessionLimitedMovesTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/22/26.
//

import Testing
@testable import NineTilesPuzzle

/// Covers `GameSession`'s Limited Moves integration: the flat per-grid-size move budget,
/// the fail state once it's exhausted, that streak tracking stays disabled (mirroring Zen),
/// and that solving still records personal-best moves/time via the existing generic
/// `recordCompletion` path.
///
/// Uses `.numbers` media mode so `startNewGame()` completes synchronously with no network
/// or image work, and replaces the shuffled board with hand-built layouts (mirroring
/// `GameSessionTimeTrialTests`) so moves can be engineered deterministically.
@Suite("GameSession – Limited Moves")
@MainActor
struct GameSessionLimitedMovesTests {
    private func makeSession(gridSize: Int = 3, settingsStore: SettingsStore? = nil) async -> GameSession {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: settingsStore ?? SettingsStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .limitedMoves
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

    @Test func startingAGameSetsTheMoveBudgetAndDoesNotFail() async {
        let session = await makeSession(gridSize: 5)
        #expect(!session.isLimitedMovesFailed)
        #expect(session.movesBudgetForCurrentSize == LimitedMovesRules.moveBudget(forGridSize: 5))
        #expect(session.limitedMovesRemaining == LimitedMovesRules.moveBudget(forGridSize: 5))
    }

    // MARK: - Flat budget

    @Test func everyMoveCostsOneRegardlessOfCorrectness() async {
        let session = await makeSession()
        let budget = session.movesBudgetForCurrentSize

        // Indices 7/8 stay wrong so this move alone can't accidentally solve the puzzle.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        session.swapTiles(from: 0, to: 1) // correct placement
        #expect(session.limitedMovesRemaining == budget - 1)

        // A full derangement: swapping 0/1 never lands either tile on its own id.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        session.swapTiles(from: 0, to: 1) // misplaced move
        #expect(session.limitedMovesRemaining == budget - 2)
    }

    // MARK: - Fail state

    @Test func runningOutOfMovesFailsAndLocksTheGrid() async {
        let session = await makeSession() // 3×3 → 12-move budget.
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])

        for _ in 0..<12 {
            session.swapTiles(from: 0, to: 1)
        }

        #expect(session.isLimitedMovesFailed)
        #expect(session.limitedMovesRemaining == 0)
        #expect(!session.isSolved)

        // The grid stops responding once failed.
        let snapshot = session.tiles.map(\.currentIndex)
        session.swapTiles(from: 0, to: 1)
        #expect(session.tiles.map(\.currentIndex) == snapshot)
    }

    @Test func aMoveThatExhaustsTheBudgetAndSolvesCountsAsAWinNotAFail() async {
        let session = await makeSession()
        let budget = session.movesBudgetForCurrentSize // 12

        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        for _ in 0..<(budget - 1) {
            session.swapTiles(from: 0, to: 1)
        }
        #expect(session.currentMoveCount == budget - 1)
        #expect(!session.isLimitedMovesFailed)

        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])
        session.swapTiles(from: 0, to: 1) // the final budgeted move also solves the puzzle

        #expect(session.isSolved)
        #expect(!session.isLimitedMovesFailed)
        #expect(session.currentMoveCount == budget)
    }

    // MARK: - Solving

    @Test func solvingRecordsPersonalBestMoves() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.isNewMovesRecord)
        #expect(session.personalBestForCurrentSize == 1)
    }

    // MARK: - Streak tracking disabled

    @Test func streakTrackingNeverEngagesInThisMode() async {
        let session = await makeSession()
        // Indices 7/8 stay wrong so this move alone can't accidentally solve the puzzle.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        session.swapTiles(from: 0, to: 1) // a correct placement, would normally start a streak

        #expect(session.currentStreakForCurrentSize == 0)
        #expect(!session.isTimerRunning)
    }

    // MARK: - Practice Mode

    @Test func practiceModeStillEnforcesTheBudgetButSkipsRecording() async {
        let settings = SettingsStore(defaults: InMemoryPersistenceStore())
        settings.debugOverlayEnabled = true
        let session = await makeSession(settingsStore: settings)

        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])
        for _ in 0..<12 {
            session.swapTiles(from: 0, to: 1)
        }

        #expect(session.isLimitedMovesFailed)
        #expect(session.personalBestForCurrentSize == nil)
    }
}
