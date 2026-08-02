//
//  GameSessionQuickSnapTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/4/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import NineTilesPuzzle

/// Covers Quick Snap's contract: it's a game, in whatever mode the player already selected,
/// whose image is a captured camera frame. `enterQuickSnapMode(with:)` leaves `selectedGameMode`
/// untouched; the captured frame is sliced directly (no fetch, no "memorize" preview); and
/// `leaveGame()` clears the Quick Snap flags, mirroring the Daily Challenge transient-flag
/// pattern minus the mode save/restore (Quick Snap never changes the mode in the first place).
@Suite("GameSession – Quick Snap")
@MainActor
struct GameSessionQuickSnapTests {
    private func makeSession() -> GameSession {
        GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            powerUpStore: PowerUpStore(defaults: InMemoryPersistenceStore()),
            challengeStore: ChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
    }

    private func makeImage(side: Int = 300) -> CGImage {
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    // MARK: - Entering

    @Test func enterQuickSnapPreservesModeAndFlagsActive() {
        let session = makeSession()
        session.selectedGameMode = .timeTrial

        session.enterQuickSnapMode(with: makeImage())

        #expect(session.isQuickSnapActive)
        #expect(session.selectedGameMode == .timeTrial)
    }

    // MARK: - Starting a game

    @Test func startNewGameUsesCapturedFrameAndSkipsPreview() async {
        let session = makeSession()
        session.gridSize = 3
        session.mediaSourceType = .camera
        session.enterQuickSnapMode(with: makeImage())

        await session.startNewGame()

        // The captured frame was sliced into a full board of image tiles.
        #expect(session.tiles.count == 9)
        #expect(session.sourceImage != nil)
        #expect(session.tileImages.count == 9)
        // No "memorize the image" phase — shuffle happens immediately.
        #expect(!session.isPreviewing)
        #expect(!session.isLoading)
    }

    @Test func quickSnapPlaysWithSwapEngineWhenSwapSelected() async {
        let session = makeSession()
        session.gridSize = 3
        session.selectedGameMode = .swap
        session.mediaSourceType = .camera
        session.enterQuickSnapMode(with: makeImage())
        await session.startNewGame()

        // Swap engine: a wrong board is solved by swapping the two out-of-place tiles.
        session.tiles = [1, 0, 2, 3, 4, 5, 6, 7, 8].enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
    }

    @Test func quickSnapPlaysWithSlideEngineWhenSlideSelected() async {
        let session = makeSession()
        session.gridSize = 3
        session.selectedGameMode = .slide
        session.mediaSourceType = .camera
        session.enterQuickSnapMode(with: makeImage())
        await session.startNewGame()

        // Slide engine: tile id 8 is the blank. One tile out of place, adjacent to the
        // blank — sliding it in should solve the board.
        session.tiles = (0..<9).map { id in
            let currentIndex = id == 7 ? 8 : (id == 8 ? 7 : id)
            return TileModel(id: id, currentIndex: currentIndex, isLocked: false)
        }
        let moved = session.slideTile(from: 8)

        #expect(moved)
        #expect(session.isSolved)
    }

    // MARK: - Stats (no exemption)

    @Test func quickSnapCountsTowardSelectedModeStatsAndStreak() async {
        let session = makeSession()
        session.gridSize = 3
        session.selectedGameMode = .swap
        session.mediaSourceType = .camera
        session.enterQuickSnapMode(with: makeImage())
        await session.startNewGame()

        // Two tiles wrong so the first correct swap doesn't also solve the puzzle.
        session.tiles = [1, 0, 2, 3, 4, 5, 6, 8, 7].enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
        session.swapTiles(from: 0, to: 1)

        // currentStatsKey follows the player's selected mode — no Quick Snap exemption.
        #expect(session.currentStatsKey.gameMode == .swap)
        #expect(session.currentStreakForCurrentSize > 0)
    }

    // MARK: - Re-capture ("Play Again")

    @Test func refreshQuickSnapImageKeepsSessionActiveAndModeUnchanged() async {
        let session = makeSession()
        session.gridSize = 3
        session.mediaSourceType = .camera
        session.selectedGameMode = .fog
        session.enterQuickSnapMode(with: makeImage())
        await session.startNewGame()

        // "Play Again" snaps a fresh frame into the same active session…
        session.refreshQuickSnapImage(with: makeImage(side: 200))
        await session.startNewGame()

        #expect(session.isQuickSnapActive)
        #expect(session.tiles.count == 9)
        #expect(session.sourceImage != nil)
        #expect(session.selectedGameMode == .fog)

        // …and leaving never touched the mode, so it's still exactly what the player picked.
        session.leaveGame()
        #expect(!session.isQuickSnapActive)
        #expect(session.selectedGameMode == .fog)
    }

    // MARK: - Leaving

    @Test func leaveGamePreservesModeAndClearsQuickSnapState() {
        let session = makeSession()
        session.selectedGameMode = .fog
        session.enterQuickSnapMode(with: makeImage())
        #expect(session.selectedGameMode == .fog)

        session.leaveGame()

        #expect(!session.isQuickSnapActive)
        #expect(session.selectedGameMode == .fog)
    }

    @Test func continueReshufflesSameShotUntilLeaving() async {
        let session = makeSession()
        session.gridSize = 3
        session.mediaSourceType = .camera
        session.enterQuickSnapMode(with: makeImage())
        await session.startNewGame()
        let firstImage = session.sourceImage

        // "Continue" (a fresh startNewGame while still active) replays the same captured frame
        // rather than falling through to a source that doesn't exist for this mode.
        await session.startNewGame()

        #expect(session.isQuickSnapActive)
        #expect(session.sourceImage != nil)
        #expect(session.tiles.count == 9)
        #expect(firstImage != nil)
    }
}
