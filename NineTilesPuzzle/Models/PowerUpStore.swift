//
//  PowerUpStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import Foundation

/// Inventory of earned power-ups. Earned rather than bought — `GameSession` awards these at
/// streak milestones, achievement unlocks, and daily-challenge completions — and spent mid-game
/// through `GameSession`'s `use...PowerUp()` methods.
@MainActor
@Observable
final class PowerUpStore {
    private let defaults: PersistenceStore

    var inventory: [PowerUpType: Int] = [:]

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        restoreFromUserDefaults()
    }

    func count(for type: PowerUpType) -> Int {
        inventory[type, default: 0]
    }

    func earn(_ type: PowerUpType, amount: Int = 1) {
        let newCount = count(for: type) + amount
        inventory[type] = newCount
        defaults.set(newCount, forKey: Keys.inventory(for: type))
    }

    /// Awards one random power-up from the currently implemented set — used by every earning
    /// trigger so growing the roster later doesn't require re-deciding which trigger gives
    /// which type.
    func earnRandom() {
        guard let type = PowerUpType.allCases.randomElement() else { return }
        earn(type)
    }

    /// Spends one `type` if available. Returns whether a power-up was actually consumed.
    @discardableResult
    func consume(_ type: PowerUpType) -> Bool {
        let current = count(for: type)
        guard current > 0 else { return false }
        inventory[type] = current - 1
        defaults.set(current - 1, forKey: Keys.inventory(for: type))
        return true
    }

    /// Refills every power-up back to `PowerUpRules.startingInventory` — used both to seed a
    /// fresh install (see `restoreFromUserDefaults()`) and as a debug utility to top inventory
    /// back up for testing.
    func resetToDefaults() {
        for type in PowerUpType.allCases {
            inventory[type] = PowerUpRules.startingInventory
            defaults.set(PowerUpRules.startingInventory, forKey: Keys.inventory(for: type))
        }
    }
}

private extension PowerUpStore {
    enum Keys {
        static func inventory(for type: PowerUpType) -> String { "powerup.inventory.\(type.rawValue)" }
    }

    /// A type that's never been persisted (fresh install, or a case added in a later update)
    /// starts at `PowerUpRules.startingInventory` rather than zero — distinguished from an
    /// already-persisted zero (earned then fully spent) via `object(forKey:)`, the same
    /// pattern `SettingsStore` uses for its optional-override preferences.
    func restoreFromUserDefaults() {
        for type in PowerUpType.allCases {
            if defaults.object(forKey: Keys.inventory(for: type)) != nil {
                inventory[type] = defaults.integer(forKey: Keys.inventory(for: type))
            } else {
                inventory[type] = PowerUpRules.startingInventory
            }
        }
    }
}
