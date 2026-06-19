//
//  PersistenceStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

/// A minimal seam over `UserDefaults` so `GameSession`, `StatsStore`, `SettingsStore`, and
/// `AchievementsStore` can be unit-tested without touching real persisted data. Mirrors the
/// handful of `UserDefaults` methods those stores actually use — `UserDefaults` itself
/// already satisfies this protocol with no extra code.
protocol PersistenceStore {
    func set(_ value: Any?, forKey defaultName: String)
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double
    func bool(forKey defaultName: String) -> Bool
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: PersistenceStore {}
