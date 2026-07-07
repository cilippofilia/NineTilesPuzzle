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

    @Test func startsWithThreeOfEveryType() {
        let store = makeStore()
        for type in PowerUpType.allCases {
            #expect(store.count(for: type) == PowerUpRules.startingInventory)
        }
    }

    @Test func earnIncrementsCount() {
        let store = makeStore()
        let startingCount = store.count(for: .peek)
        store.earn(.peek)
        store.earn(.peek)
        #expect(store.count(for: .peek) == startingCount + 2)
        #expect(store.count(for: .autoPlace) == PowerUpRules.startingInventory)
    }

    @Test func earnWithAmountAddsMultiple() {
        let store = makeStore()
        let startingCount = store.count(for: .autoPlace)
        store.earn(.autoPlace, amount: 3)
        #expect(store.count(for: .autoPlace) == startingCount + 3)
    }

    @Test func consumeDecrementsWhenAvailable() {
        let store = makeStore()
        let startingCount = store.count(for: .peek)
        #expect(store.consume(.peek))
        #expect(store.count(for: .peek) == startingCount - 1)
    }

    @Test func consumeFailsAtZero() {
        let store = makeStore()
        for _ in 0..<PowerUpRules.startingInventory {
            #expect(store.consume(.peek))
        }
        #expect(!store.consume(.peek))
        #expect(store.count(for: .peek) == 0)
    }

    @Test func earnRandomAwardsOneOfTheImplementedTypes() {
        let store = makeStore()
        let totalBefore = PowerUpType.allCases.reduce(0) { $0 + store.count(for: $1) }
        store.earnRandom()
        let totalAfter = PowerUpType.allCases.reduce(0) { $0 + store.count(for: $1) }
        #expect(totalAfter == totalBefore + 1)
    }

    @Test func inventoryPersistsAcrossInstances() {
        let defaults = InMemoryPersistenceStore()
        let store = PowerUpStore(defaults: defaults)
        store.earn(.peek, amount: 2)
        store.consume(.autoPlace)

        let restored = PowerUpStore(defaults: defaults)
        #expect(restored.count(for: .peek) == PowerUpRules.startingInventory + 2)
        #expect(restored.count(for: .autoPlace) == PowerUpRules.startingInventory - 1)
    }

    @Test func resetToDefaultsRefillsEveryType() {
        let store = makeStore()
        store.consume(.peek)
        store.consume(.hint)
        store.earn(.reshuffle, amount: 5)

        store.resetToDefaults()

        for type in PowerUpType.allCases {
            #expect(store.count(for: type) == PowerUpRules.startingInventory)
        }
    }

    @Test func newTypeAddedLaterStartsAtDefaultEvenWithOtherPersistedTypes() {
        let defaults = InMemoryPersistenceStore()
        let store = PowerUpStore(defaults: defaults)
        store.consume(.peek)

        let restored = PowerUpStore(defaults: defaults)
        #expect(restored.count(for: .peek) == PowerUpRules.startingInventory - 1)
        #expect(restored.count(for: .hint) == PowerUpRules.startingInventory)
    }
}
