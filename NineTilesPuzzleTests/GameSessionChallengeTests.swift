//
//  GameSessionChallengeTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/8/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import NineTilesPuzzle

/// Covers Challenge Friends' receiving/playing contract: `enterChallengeMode(with:)` forces
/// the challenge's mode/grid size and remembers the player's own mode (mirroring Quick
/// Snap); the embedded image is decoded directly (no fetch); the board is shuffled from the
/// challenge's own seed, matching a direct `SeededShuffle` call; and completion routes into
/// `ChallengeStore`, never `StatsStore`.
@Suite("GameSession – Challenge Friends")
@MainActor
struct GameSessionChallengeTests {
    private func makeSession(
        statsStore: StatsStore? = nil,
        challengeStore: ChallengeStore? = nil,
        settingsStore: SettingsStore? = nil
    ) -> GameSession {
        GameSession(
            statsStore: statsStore ?? StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: settingsStore ?? SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            powerUpStore: PowerUpStore(defaults: InMemoryPersistenceStore()),
            challengeStore: challengeStore ?? ChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
    }

    /// A flat-filled test image — solid color, so JPEG round-tripping through
    /// `ChallengeImageCodec` doesn't introduce edge-compression artifacts that would
    /// complicate a pixel comparison.
    private func makeImage(side: Int = 120, red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()!
    }

    private func makeChallenge(
        gameMode: GameMode = .swap,
        gridSize: Int = 3,
        seed: UInt64 = 12345,
        senderMoves: Int = 20,
        senderTime: TimeInterval = 45,
        image: CGImage? = nil
    ) -> FriendChallenge {
        let source = image ?? makeImage(red: 0.2, green: 0.5, blue: 0.8)
        let data = ChallengeImageCodec.encode(source)!
        return FriendChallenge(
            senderName: "Alex",
            gameMode: gameMode,
            gridSize: gridSize,
            seed: seed,
            imageData: data,
            senderMoves: senderMoves,
            senderTime: senderTime
        )
    }

    /// Reads the color at the image's center pixel — enough to distinguish "reoriented" from
    /// "untouched" for a flat-filled test image, without needing a full pixel-buffer compare.
    private func centerColor(of image: CGImage) -> (r: UInt8, g: UInt8, b: UInt8) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let x = -CGFloat(image.width) / 2 + 0.5
        let y = -CGFloat(image.height) / 2 + 0.5
        context.draw(image, in: CGRect(x: x, y: y, width: CGFloat(image.width), height: CGFloat(image.height)))
        return (pixel[0], pixel[1], pixel[2])
    }

    // MARK: - Entering

    @Test func enterChallengeModeForcesModeGridSizeAndClearsLadder() {
        let session = makeSession()
        session.selectedGameMode = .timeTrial
        session.isLadderMode = true
        session.gridSize = 6

        let challenge = makeChallenge(gameMode: .limitedMoves, gridSize: 4)
        session.enterChallengeMode(with: challenge)

        #expect(session.isChallengeGameActive)
        #expect(session.selectedGameMode == .limitedMoves)
        #expect(session.gridSize == 4)
        #expect(!session.isLadderMode)
        #expect(session.activeChallenge?.id == challenge.id)
        #expect(session.challengeOutcome == nil)
    }

    // MARK: - Starting a game

    @Test func startNewGameDecodesEmbeddedImage() async {
        let session = makeSession()
        let challenge = makeChallenge()
        session.enterChallengeMode(with: challenge)

        await session.startNewGame()

        #expect(session.tiles.count == 9)
        #expect(session.sourceImage != nil)
        #expect(session.tileImages.count == 9)
    }

    @Test func startNewGameShufflesFromTheChallengeSeedForSwap() async {
        let session = makeSession()
        let challenge = makeChallenge(gameMode: .swap, gridSize: 3, seed: 777)
        session.enterChallengeMode(with: challenge)

        await session.startNewGame()

        let expected = SeededShuffle.shuffledPositions(count: 9, seed: 777)
        let actual = (0..<9).map { id in session.tiles.first { $0.id == id }!.currentIndex }
        #expect(actual == expected)
    }

    @Test func startNewGameShufflesFromTheChallengeSeedForSlide() async {
        let session = makeSession()
        let challenge = makeChallenge(gameMode: .slide, gridSize: 3, seed: 999)
        session.enterChallengeMode(with: challenge)

        await session.startNewGame()

        let expectedBoard = SeededShuffle.shuffledSlideBoard(count: 9, gridSize: 3, seed: 999)
        let actual = (0..<9).map { position in session.tiles.first { $0.currentIndex == position }!.id }
        #expect(actual == expectedBoard)
    }

    @Test func chaosChallengeSkipsTheTransformReRoll() async {
        let session = makeSession()
        // Distinct, non-gray fill: any orientation/tone transform (mirror, flip, rotate,
        // invert, desaturate, hue-shift, sepia) changes a flat color's channel values or
        // position enough that "no re-roll happened" is distinguishable from "one did".
        let original = makeImage(red: 0.15, green: 0.6, blue: 0.35)
        let challenge = makeChallenge(gameMode: .chaos, image: original)
        session.enterChallengeMode(with: challenge)

        await session.startNewGame()

        let expected = centerColor(of: original)
        let actual = centerColor(of: session.croppedSourceImage!)
        // Generous tolerance for JPEG quantization — a real re-transform (e.g. invert or
        // sepia) would move these channels by far more than compression noise ever would.
        #expect(abs(Int(actual.r) - Int(expected.r)) < 12)
        #expect(abs(Int(actual.g) - Int(expected.g)) < 12)
        #expect(abs(Int(actual.b) - Int(expected.b)) < 12)
    }

    // MARK: - Completion routing

    @Test func solvingRoutesCompletionIntoChallengeStoreNotStatsStore() async {
        let stats = StatsStore(defaults: InMemoryPersistenceStore())
        let challenges = ChallengeStore(defaults: InMemoryPersistenceStore())
        let session = makeSession(statsStore: stats, challengeStore: challenges)

        let challenge = makeChallenge(gameMode: .swap, gridSize: 3, senderMoves: 40)
        challenges.registerReceived(challenge, transport: .file)
        session.enterChallengeMode(with: challenge)
        await session.startNewGame()

        // Force a deterministic wrong-then-fixed board so one swap solves it.
        session.tiles = [1, 0, 2, 3, 4, 5, 6, 7, 8].enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.challengeOutcome == .won)
        #expect(challenges.records.first { $0.id == challenge.id }?.outcome == .won)
        // The per-`StatsKey` bests must stay untouched by a challenge completion.
        #expect(stats.personalBestMoves[StatsKey(gridSize: 3, gameMode: .swap)] == nil)
    }

    @Test func debugOverlaySuppressesChallengeRecording() async {
        let settings = SettingsStore(defaults: InMemoryPersistenceStore())
        settings.setDebugOverlayEnabled(true)
        let challenges = ChallengeStore(defaults: InMemoryPersistenceStore())
        let session = makeSession(challengeStore: challenges, settingsStore: settings)

        let challenge = makeChallenge(gameMode: .swap, gridSize: 3)
        challenges.registerReceived(challenge, transport: .file)
        session.enterChallengeMode(with: challenge)
        await session.startNewGame()

        session.tiles = [1, 0, 2, 3, 4, 5, 6, 7, 8].enumerated().map { index, id in
            TileModel(id: id, currentIndex: index, isLocked: false)
        }
        session.swapTiles(from: 0, to: 1)

        #expect(session.isSolved)
        #expect(session.challengeOutcome == nil)
        #expect(challenges.records.first { $0.id == challenge.id }?.outcome == nil)
    }

    // MARK: - Leaving

    @Test func leaveGameRestoresModeAndClearsChallengeState() {
        let session = makeSession()
        session.selectedGameMode = .fog
        let challenge = makeChallenge(gameMode: .swap)
        session.enterChallengeMode(with: challenge)
        #expect(session.selectedGameMode == .swap)

        session.leaveGame()

        #expect(!session.isChallengeGameActive)
        #expect(session.activeChallenge == nil)
        #expect(session.challengeOutcome == nil)
        #expect(session.selectedGameMode == .fog)
    }
}
