//
//  GameSessionPowerUpApplicabilityTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/8/26.
//

import CoreGraphics
import Testing
@testable import NineTilesPuzzle

/// Covers `GameSession.isPowerUpApplicable(_:)` — the rule that keeps the toolbar from
/// offering power-ups whose purpose can't do anything in the current mode (a numbers board
/// has nothing to Peek at, Slide has no locked tiles for Auto-place/Re-shuffle, and only the
/// streak-countdown modes have a streak to Freeze).
///
/// Uses `.numbers` media mode so `startNewGame()` completes synchronously; `previewImage` is
/// then set by hand to stand in for an image-backed board where a test needs one.
@Suite("GameSession – Power-up applicability")
@MainActor
struct GameSessionPowerUpApplicabilityTests {
    private func makeSession(mode: GameMode) async -> GameSession {
        let session = GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            powerUpStore: PowerUpStore(defaults: InMemoryPersistenceStore()),
            challengeStore: ChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: InMemoryPersistenceStore()
        )
        session.selectedGameMode = mode
        session.mediaSourceType = .numbers
        session.gridSize = 3
        await session.startNewGame()
        return session
    }

    /// A 1×1 opaque bitmap — enough for a non-nil `previewImage` in tests that need one.
    private func stubImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    // MARK: - Peek

    @Test func peekIsUnavailableWithoutAReferenceImage() async {
        let session = await makeSession(mode: .swap)
        session.previewImage = nil
        #expect(!session.isPowerUpApplicable(.peek))
    }

    @Test func peekBecomesAvailableOnceThereIsAnImage() async {
        let session = await makeSession(mode: .swap)
        session.previewImage = stubImage()
        #expect(session.isPowerUpApplicable(.peek))
    }

    // MARK: - Slide's tile-locking power-ups

    @Test func autoPlaceAndReshuffleAreUnavailableInSlide() async {
        let session = await makeSession(mode: .slide)
        #expect(!session.isPowerUpApplicable(.autoPlace))
        #expect(!session.isPowerUpApplicable(.reshuffle))
    }

    @Test func autoPlaceAndReshuffleAreAvailableOutsideSlide() async {
        let session = await makeSession(mode: .swap)
        #expect(session.isPowerUpApplicable(.autoPlace))
        #expect(session.isPowerUpApplicable(.reshuffle))
    }

    // MARK: - Hint

    @Test func hintIsAvailableInEveryMode() async {
        for mode in [GameMode.slide, .swap, .timeTrial, .limitedMoves, .fog, .chaos] {
            let session = await makeSession(mode: mode)
            #expect(session.isPowerUpApplicable(.hint))
        }
    }

    // MARK: - Streak Freeze

    @Test func streakFreezeIsAvailableInStreakCountdownModes() async {
        for mode in [GameMode.slide, .swap, .fog, .chaos] {
            let session = await makeSession(mode: mode)
            #expect(session.isPowerUpApplicable(.streakFreeze))
        }
    }

    @Test func streakFreezeIsUnavailableWhereNoStreakCountdownRuns() async {
        for mode in [GameMode.timeTrial, .limitedMoves, .zen] {
            let session = await makeSession(mode: mode)
            #expect(!session.isPowerUpApplicable(.streakFreeze))
        }
    }

    // MARK: - The screenshot's Slide + numbers board

    @Test func slideNumbersBoardOnlyOffersHintAndStreakFreeze() async {
        let session = await makeSession(mode: .slide) // numbers media → no preview image
        #expect(!session.isPowerUpApplicable(.peek))
        #expect(!session.isPowerUpApplicable(.autoPlace))
        #expect(!session.isPowerUpApplicable(.reshuffle))
        #expect(session.isPowerUpApplicable(.hint))
        #expect(session.isPowerUpApplicable(.streakFreeze))
    }
}
