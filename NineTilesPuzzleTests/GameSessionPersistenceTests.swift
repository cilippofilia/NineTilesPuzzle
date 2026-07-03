//
//  GameSessionPersistenceTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/3/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import NineTilesPuzzle

/// Guards the split between the cheap per-move persistence (`saveDynamicState`) and the full
/// persist that also re-encodes the source image (`saveToUserDefaults`). The whole point of
/// the split is that a tile move must never pay the image-JPEG cost, so these tests pin down
/// which keys each path writes, plus a full save→restore round-trip that rebuilds the sliced
/// tile images.
@Suite("GameSession – Persistence")
@MainActor
struct GameSessionPersistenceTests {
    private func makeSession(store: PersistenceStore) -> GameSession {
        GameSession(
            statsStore: StatsStore(defaults: InMemoryPersistenceStore()),
            achievementsStore: AchievementsStore(defaults: InMemoryPersistenceStore()),
            settingsStore: SettingsStore(defaults: InMemoryPersistenceStore()),
            dailyChallengeStore: DailyChallengeStore(defaults: InMemoryPersistenceStore()),
            defaults: store
        )
    }

    private func makeTestImage(width: Int = 60, height: Int = 60) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test func saveDynamicStateDoesNotTouchTheImageKey() {
        let store = InMemoryPersistenceStore()
        let session = makeSession(store: store)
        session.sourceImage = makeTestImage()
        session.tiles = [TileModel(id: 0, currentIndex: 0, isLocked: false)]

        session.saveDynamicState()

        // The expensive image encode must be absent from the per-move path...
        #expect(store.data(forKey: GameSession.Keys.sourceImage) == nil)
        // ...while the cheap tile state is still written.
        #expect(store.data(forKey: GameSession.Keys.tiles) != nil)
    }

    @Test func fullSaveWritesTheImageKey() {
        let store = InMemoryPersistenceStore()
        let session = makeSession(store: store)
        session.sourceImage = makeTestImage()
        session.tiles = [TileModel(id: 0, currentIndex: 0, isLocked: false)]

        session.saveToUserDefaults()

        #expect(store.data(forKey: GameSession.Keys.sourceImage) != nil)
        #expect(store.data(forKey: GameSession.Keys.tiles) != nil)
    }

    @Test func saveDynamicStatePersistsMoveCountAndElapsedTime() {
        let store = InMemoryPersistenceStore()
        let session = makeSession(store: store)
        session.currentMoveCount = 7
        session.elapsedTime = 12.5

        session.saveDynamicState()

        #expect(store.integer(forKey: GameSession.Keys.currentMoveCount) == 7)
        #expect(store.double(forKey: GameSession.Keys.elapsedTime) == 12.5)
    }

    @Test func fullSaveThenRestoreReconstructsTilesAndTileImages() {
        let store = InMemoryPersistenceStore()

        let saved = makeSession(store: store)
        saved.mediaSourceType = .random // image-backed mode, so restore re-slices the image
        saved.gridSize = 3
        saved.sourceImage = makeTestImage()
        saved.tiles = (0..<9).map { TileModel(id: $0, currentIndex: $0, isLocked: false) }
        saved.saveToUserDefaults()

        // A fresh session over the same store restores in its initializer.
        let restored = makeSession(store: store)

        #expect(restored.gridSize == 3)
        #expect(restored.tiles.count == 9)
        #expect(restored.sourceImage != nil)
        // Every tile position must get a sliced image back after restore.
        #expect(restored.tileImages.count == 9)
    }
}
