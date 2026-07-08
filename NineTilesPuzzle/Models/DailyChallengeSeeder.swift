//
//  DailyChallengeSeeder.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import Foundation

/// Deterministic seed-generation for the Daily Challenge. Everything here is pure and
/// date-deterministic — the same calendar day always produces the same image URL, game
/// mode, and grid size, so every player sees an identical puzzle. The seeded tile shuffle
/// itself lives in `SeededShuffle`, shared with Challenge Friends.
enum DailyChallengeSeeder {
    static let availableGridSizes = [4, 5, 6]
    static let availableGameModes: [GameMode] = [.slide, .swap, .limitedMoves]

    /// Returns a `UInt64` seed derived from the calendar date of `date`.
    /// Uses `Calendar.current` so the seed respects the device's time zone — the
    /// same calendar day everywhere yields the same puzzle.
    static func seed(for date: Date = .now) -> UInt64 {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(comps.year ?? 2026)
        let m = UInt64(comps.month ?? 1)
        let d = UInt64(comps.day ?? 1)
        return y * 10000 + m * 100 + d
    }

    /// Picsum "seed" URL — returns a consistent image for the same seed string.
    /// The `ntp-YYYY-MM-DD` prefix avoids collisions with any other picsum consumer.
    /// Picsum serves the same source photo for a seed at any size, so smaller `size`
    /// values (e.g. calendar thumbnails) show the same picture as the full puzzle.
    static func imageURL(for date: Date = .now, size: Int = 1024) -> URL {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let seedString = String(format: "ntp-%04d-%02d-%02d", y, m, d)
        return URL(string: "https://picsum.photos/seed/\(seedString)/\(size)/\(size)")!
    }

    /// Returns today's grid size, deterministically chosen from `availableGridSizes`.
    static func gridSize(for date: Date = .now) -> Int {
        var rng = SeededGenerator(seed: seed(for: date) ^ 0x9e3779b97f4a7c15)
        return availableGridSizes[Int(rng.next() % UInt64(availableGridSizes.count))]
    }

    /// Returns today's game mode, deterministically chosen from `availableGameModes`.
    static func gameMode(for date: Date = .now) -> GameMode {
        var rng = SeededGenerator(seed: seed(for: date) ^ 0x517cc1b727220a95)
        return availableGameModes[Int(rng.next() % UInt64(availableGameModes.count))]
    }

}
