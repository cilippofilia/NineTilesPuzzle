//
//  GameSessionBestsSnapshotTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 10/24/26.
//

import Testing
@testable import NineTilesPuzzle

/// `GameSession.bestsBeforeSolve` must hold the bests as they were *before* a solve was
/// recorded, so the completion panel can say what a new best replaced.
@Suite("GameSession – bests before solve")
@MainActor
struct GameSessionBestsSnapshotTests {
    private func makeSession(debugOverlay: Bool = false) async -> GameSession {
        let settings = SettingsStore(defaults: InMemoryPersistenceStore())
        settings.debugOverlayEnabled = debugOverlay
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: settings,
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            powerUpStore: PowerUpStore(defaults: InMemoryPersistenceStore()),
            challengeStore: ChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .swap
        session.mediaSourceType = .numbers
        session.gridSize = 3
        await session.startNewGame()
        return session
    }

    /// Lays out a board one swap (indices 0 and 1) away from solved, then makes that swap.
    private func solveInOneMove(_ session: GameSession) {
        session.tiles = [1, 0, 2, 3, 4, 5, 6, 7, 8].enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
        session.swapTiles(from: 0, to: 1)
    }

    @Test func firstSolveSnapshotsEmptyBests() async {
        let session = await makeSession()
        solveInOneMove(session)
        #expect(session.isSolved)
        #expect(session.bestsBeforeSolve == PersonalBestSnapshot())
    }

    @Test func secondSolveSnapshotsTheBestsTheFirstSolveSet() async {
        let session = await makeSession()
        solveInOneMove(session)
        let firstMoves = session.currentMoveCount

        await session.startNewGame()
        #expect(session.bestsBeforeSolve == nil)
        solveInOneMove(session)

        #expect(session.bestsBeforeSolve?.moves == firstMoves)
        #expect(session.bestsBeforeSolve?.time != nil)
    }

    @Test func rankedBestsTrackTheLiveRecordsUntilTheNextSolve() async {
        let session = await makeSession()
        #expect(session.rankedPersonalBests == PersonalBestSnapshot())
        solveInOneMove(session)
        #expect(session.rankedPersonalBests?.moves == session.currentMoveCount)
    }

    @Test func practiceSolvesAreNotRanked() async {
        let session = await makeSession(debugOverlay: true)
        solveInOneMove(session)
        #expect(session.isSolved)
        #expect(session.bestsBeforeSolve == nil)
        #expect(session.rankedPersonalBests == nil)
    }
}
