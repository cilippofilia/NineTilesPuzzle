//
//  PowerUpStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/7/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("PowerUpStore")
@MainActor
struct PowerUpStoreTests {
    private func makeStore() -> PowerUpStore {
        PowerUpStore(defaults: InMemoryPersistenceStore())
    }

    @Test func startsWithEmptyInventory() {
        let store = makeStore()
        #expect(store.count(for: .peek) == 0)
        #expect(store.count(for: .autoPlace) == 0)
    }

    @Test func earnIncrementsCount() {
        let store = makeStore()
        store.earn(.peek)
        store.earn(.peek)
        #expect(store.count(for: .peek) == 2)
        #expect(store.count(for: .autoPlace) == 0)
    }

    @Test func earnWithAmountAddsMultiple() {
        let store = makeStore()
        store.earn(.autoPlace, amount: 3)
        #expect(store.count(for: .autoPlace) == 3)
    }

    @Test func consumeDecrementsWhenAvailable() {
        let store = makeStore()
        store.earn(.peek)
        #expect(store.consume(.peek))
        #expect(store.count(for: .peek) == 0)
    }

    @Test func consumeFailsAtZero() {
        let store = makeStore()
        #expect(!store.consume(.peek))
        #expect(store.count(for: .peek) == 0)
    }

    @Test func earnRandomAwardsOneOfTheImplementedTypes() {
        let store = makeStore()
        store.earnRandom()
        let total = store.count(for: .peek) + store.count(for: .autoPlace)
        #expect(total == 1)
    }

    @Test func inventoryPersistsAcrossInstances() {
        let defaults = InMemoryPersistenceStore()
        let store = PowerUpStore(defaults: defaults)
        store.earn(.peek, amount: 2)
        store.earn(.autoPlace)

        let restored = PowerUpStore(defaults: defaults)
        #expect(restored.count(for: .peek) == 2)
        #expect(restored.count(for: .autoPlace) == 1)
    }
}
