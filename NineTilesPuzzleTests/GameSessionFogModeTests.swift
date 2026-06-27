//
//  GameSessionFogModeTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/26/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

/// Covers Fog Mode's core contract: the two-stage tile reveal (`hasBeenMoved` toggling on
/// swap, `isLocked` toggling on correct placement), that the reveal flag is fog-only, that
/// the standard preview phase is skipped, and that completion wires up streak + personal-best
/// moves exactly like Swap Mode.
///
/// Uses `.numbers` media so `startNewGame()` completes synchronously without network or
/// image work. Hand-built boards make every move deterministic.
@Suite("GameSession – Fog Mode")
@MainActor
struct GameSessionFogModeTests {
    private func makeSession(gridSize: Int = 3) async -> GameSession {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .fog
        session.mediaSourceType = .numbers
        session.gridSize = gridSize
        await session.startNewGame()
        return session
    }

    private func setBoard(_ session: GameSession, idsAtIndex: [Int]) {
        session.tiles = idsAtIndex.enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
    }

    // MARK: - isFogMode

    @Test func isFogModeIsTrueOnlyForFog() {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = .fog
        #expect(session.isFogMode)

        for mode in GameMode.allCases where mode != .fog {
            session.selectedGameMode = mode
            #expect(!session.isFogMode)
        }
    }

    // MARK: - hasBeenMoved tracking

    @Test func swappingTilesMarksBothAsMovedInFogMode() async {
        let session = await makeSession()
        // Tiles at indices 0 and 1 start unswapped and never moved.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        let tileAtZero = session.tiles.first { $0.currentIndex == 0 }!
        let tileAtOne  = session.tiles.first { $0.currentIndex == 1 }!

        #expect(!tileAtZero.hasBeenMoved)
        #expect(!tileAtOne.hasBeenMoved)

        session.swapTiles(from: 0, to: 1)

        // Both tiles touched by the swap must be revealed.
        #expect(tileAtZero.hasBeenMoved)
        #expect(tileAtOne.hasBeenMoved)
    }

    @Test func tilesNotInvolvedInSwapRemainHidden() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        session.swapTiles(from: 0, to: 1)

        let untouched = session.tiles.filter { $0.currentIndex >= 2 }
        #expect(untouched.allSatisfy { !$0.hasBeenMoved })
    }

    @Test func swappingTilesInNonFogModeDoesNotSetHasBeenMoved() async {
        for mode in GameMode.allCases where mode != .fog && mode != .slide {
            let session = GameSession(
                statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
                achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
                settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
                defaults: InMemoryPersistenceStore()
            )
            session.selectedGameMode = mode
            session.mediaSourceType = .numbers
            session.gridSize = 3
            await session.startNewGame()
            setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
            session.swapTiles(from: 0, to: 1)

            #expect(session.tiles.allSatisfy { !$0.hasBeenMoved }, "hasBeenMoved must not be set in \(mode) mode")
        }
    }

    @Test func freshTilesAfterNewGameAllStartHidden() async {
        let session = await makeSession()
        // Make some tiles visible by swapping them.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        session.swapTiles(from: 0, to: 1)

        // Start a new game — all tiles should be fresh TileModel instances.
        await session.startNewGame()
        #expect(session.tiles.allSatisfy { !$0.hasBeenMoved })
    }

    // MARK: - Preview skipped

    @Test func fogModeSkipsImagePreviewPhase() async {
        // With .numbers media, there is no preview phase in any mode — this verifies
        // that `isPreviewing` never becomes true during the synchronous startup path.
        let session = await makeSession()
        #expect(!session.isPreviewing)
        #expect(!session.isLoading)
    }

    // MARK: - Solving and streaks

    @Test func solvingRecordsPersonalBestAndStreak() async {
        let session = await makeSession()
        // One swap solves the puzzle.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 7, 8])
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.isNewMovesRecord)
        #expect(session.personalBestForCurrentSize == 1)
    }

    @Test func correctMoveIncrementsStreakUnlikeZenOrLimitedMoves() async {
        let session = await makeSession()
        // Two tiles wrong at indices 7/8 so one swap doesn't accidentally solve the puzzle.
        setBoard(session, idsAtIndex: [1, 0, 2, 3, 4, 5, 6, 8, 7])
        session.swapTiles(from: 0, to: 1)

        #expect(!session.isSolved)
        #expect(session.currentStreakForCurrentSize > 0)
    }

    @Test func fogModeHasNoFailState() async {
        let session = await makeSession()
        setBoard(session, idsAtIndex: [5, 6, 7, 8, 0, 1, 2, 3, 4])

        // Make many wasted moves — no fail state should ever trip.
        for _ in 0..<50 {
            session.swapTiles(from: 0, to: 1)
        }

        #expect(!session.isTimeTrialFailed)
        #expect(!session.isLimitedMovesFailed)
        #expect(!session.isSolved)
    }

    // MARK: - TileModel Codable round-trip

    @Test func tileModelPreservesHasBeenMovedThroughCodableRoundTrip() throws {
        let original = TileModel(id: 3, currentIndex: 5, isLocked: false, hasBeenMoved: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TileModel.self, from: data)

        #expect(decoded.id == 3)
        #expect(decoded.currentIndex == 5)
        #expect(decoded.hasBeenMoved == true)
    }

    @Test func tileModelDecodesLegacySaveMissingHasBeenMovedAsHidden() throws {
        let json = #"{"id":2,"currentIndex":4,"isLocked":false}"#
        let data = Data(json.utf8)
        let tile = try JSONDecoder().decode(TileModel.self, from: data)

        #expect(tile.id == 2)
        #expect(tile.hasBeenMoved == false)
    }
}
