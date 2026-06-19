//
//  InMemoryPersistenceStore.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation
@testable import NineTilesPuzzle

/// A `PersistenceStore` fake backed by an in-memory dictionary — no disk I/O, no shared
/// state with the app's real `UserDefaults.standard`, and no cleanup needed between tests.
final class InMemoryPersistenceStore: PersistenceStore {
    private var storage: [String: Any] = [:]

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    func integer(forKey defaultName: String) -> Int {
        storage[defaultName] as? Int ?? 0
    }

    func double(forKey defaultName: String) -> Double {
        storage[defaultName] as? Double ?? 0
    }

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
