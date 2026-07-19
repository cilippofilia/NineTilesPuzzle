//
//  SeededShuffle.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation

/// Mode-agnostic, seed-driven tile shuffling. Given the same `count`/`gridSize`/`seed`,
/// every call produces an identical result — used anywhere two devices need to agree on a
/// starting board without exchanging the board itself, such as Daily Challenge (seeded from
/// the calendar date) and Challenge Friends (seeded at share time).
enum SeededShuffle {
    /// Returns a deterministic derangement (no tile stays in its original slot)
    /// of `count` positions, using `seed` to drive a seeded xorshift64 PRNG.
    /// Identical `count` + `seed` always produces the same permutation.
    /// Use for swap-style and limited-moves puzzles.
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
    /// Use for slide-mode puzzles.
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
/// Not `private` — `DailyChallengeSeeder` also reuses it directly for pool selection.
struct SeededGenerator: RandomNumberGenerator {
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
