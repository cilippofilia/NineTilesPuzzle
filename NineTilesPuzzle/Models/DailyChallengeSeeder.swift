//
//  DailyChallengeSeeder.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import Foundation

/// Deterministic seed-generation and tile-shuffling for the Daily Challenge.
/// Everything here is pure and date-deterministic — the same calendar day always
/// produces the same image URL, game mode, grid size, and tile arrangement,
/// so every player sees an identical puzzle.
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

    /// Returns a deterministic derangement (no tile stays in its original slot)
    /// of `count` positions, using `seed` to drive a seeded xorshift64 PRNG.
    /// Identical `count` + `seed` always produces the same permutation.
    /// Use for swap-style and limited-moves daily puzzles.
    static func shuffledPositions(count: Int, seed: UInt64) -> [Int] {
        var rng = SeededGenerator(seed: seed)
        var positions = Array(0..<count)
        repeat {
            positions.shuffle(using: &rng)
        } while positions.enumerated().contains(where: { $0.offset == $0.element })
        return positions
    }

    /// Returns a deterministic, solvable board layout for a sliding puzzle.
    /// `board[position]` is the tile id occupying that position; the blank tile
    /// has id `count - 1`. Only half of all permutations are solvable; the algorithm
    /// mirrors `SlideEngine.shuffle` — if a seeded shuffle lands on an unsolvable
    /// permutation, swapping two non-blank tiles flips parity and restores solvability.
    /// Use for slide-mode daily puzzles.
    static func shuffledSlideBoard(count: Int, gridSize: Int, seed: UInt64) -> [Int] {
        let blankID = count - 1
        var rng = SeededGenerator(seed: seed)
        var board = Array(0..<count)
        repeat {
            board.shuffle(using: &rng)
            if !isSolvable(board, blankID: blankID, gridSize: gridSize) {
                let blankPosition = board.firstIndex(of: blankID)!
                let others = (0..<count).filter { $0 != blankPosition }
                board.swapAt(others[0], others[1])
            }
        } while board == Array(0..<count)
        return board
    }

    /// Standard sliding-puzzle solvability check. `permutation[position]` is the tile id
    /// at that grid position. Mirrors `SlideEngine.isSolvable` exactly.
    private static func isSolvable(_ permutation: [Int], blankID: Int, gridSize: Int) -> Bool {
        let sequence = permutation.filter { $0 != blankID }
        var inversions = 0
        for i in 0..<sequence.count {
            for j in (i + 1)..<sequence.count where sequence[i] > sequence[j] {
                inversions += 1
            }
        }
        guard gridSize % 2 == 0 else { return inversions % 2 == 0 }
        let blankPosition = permutation.firstIndex(of: blankID)!
        let blankRowFromBottom = (gridSize - 1) - (blankPosition / gridSize)
        return (inversions + blankRowFromBottom) % 2 == 0
    }
}

/// Xorshift64 PRNG — fast, seedable, and well-distributed for tile counts ≤ 64.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state, which would produce an infinite sequence of zeros.
        state = seed == 0 ? 6364136223846793005 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
