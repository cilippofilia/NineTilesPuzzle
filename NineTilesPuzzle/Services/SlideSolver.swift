//
//  SlideSolver.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

/// Computes a sequence of slide moves that brings a slide-mode board to its solved state.
///
/// Each returned value is a grid index suitable for `PuzzleState.slideTile(from:)`: the
/// position of the tile that slides into the empty cell for that step.
///
/// For a 3x3 board the solution is found directly via breadth-first search over the whole
/// board (only ~180k reachable states). Larger boards are solved using the classic
/// row-by-row, then column-by-column reduction: each row (except the last two) is solved
/// left to right, with its final two tiles placed together, and the remaining two-row strip
/// is then solved column by column the same way, leaving a final 2x3 block that's solved
/// directly via breadth-first search.
///
/// Each placement step (one or two tiles) is itself solved via breadth-first search over the
/// reduced state of "tracked tile position(s) + blank position" within the still-unsolved
/// region. This avoids the classic pitfall of a naive single-step approach, where the blank
/// can become trapped in a dead-end cell while trying to nudge a tile that's already adjacent
/// to its target.
@MainActor
struct SlideSolver {
    func solve(tiles: [TileModel], gridSize: Int) -> [Int] {
        let n = gridSize
        guard n >= 3 else { return [] }

        let blankID = n * n - 1
        var board = [Int](repeating: 0, count: n * n)
        for tile in tiles { board[tile.currentIndex] = tile.id }

        if n == 3 {
            return solveWholeBoard(board: board, gridSize: n)
        }

        var moves: [Int] = []
        var frozen = Set<Int>()

        func pos(_ row: Int, _ col: Int) -> Int { row * n + col }

        func neighbors(of position: Int) -> [Int] {
            let row = position / n
            let col = position % n
            var result: [Int] = []
            if row > 0 { result.append(pos(row - 1, col)) }
            if row < n - 1 { result.append(pos(row + 1, col)) }
            if col > 0 { result.append(pos(row, col - 1)) }
            if col < n - 1 { result.append(pos(row, col + 1)) }
            return result
        }

        func performMove(_ sourcePosition: Int) {
            let blank = board.firstIndex(of: blankID)!
            moves.append(sourcePosition)
            board.swapAt(blank, sourcePosition)
        }

        /// Brings a single tile to its target via BFS over (tile position, blank position)
        /// within the still-unsolved region.
        func solveOneTile(tileID: Int, target: Int, blocked: Set<Int>) {
            struct State: Hashable { var tile: Int; var blank: Int }

            let start = State(tile: board.firstIndex(of: tileID)!, blank: board.firstIndex(of: blankID)!)
            if start.tile == target { return }

            var queue = [start]
            var visited: Set<State> = [start]
            var parent: [State: (State, Int)] = [:]
            var head = 0
            var goal: State?
            while head < queue.count {
                let state = queue[head]
                head += 1
                if state.tile == target { goal = state; break }
                for next in neighbors(of: state.blank) where !blocked.contains(next) {
                    var nextState = state
                    nextState.blank = next
                    if next == state.tile { nextState.tile = state.blank }
                    if !visited.contains(nextState) {
                        visited.insert(nextState)
                        parent[nextState] = (state, next)
                        queue.append(nextState)
                    }
                }
            }

            guard let goal else { return }
            var path: [Int] = []
            var current = goal
            while let (previous, move) = parent[current] {
                path.append(move)
                current = previous
            }
            for step in path.reversed() { performMove(step) }
        }

        /// Brings two tiles to their final targets via BFS over (tile A position, tile B
        /// position, blank position) within the still-unsolved region.
        func solveTwoTiles(firstID: Int, secondID: Int, targetA: Int, targetB: Int, blocked: Set<Int>) {
            struct State: Hashable { var a: Int; var b: Int; var blank: Int }

            let start = State(
                a: board.firstIndex(of: firstID)!,
                b: board.firstIndex(of: secondID)!,
                blank: board.firstIndex(of: blankID)!
            )
            if start.a == targetA && start.b == targetB { return }

            var queue = [start]
            var visited: Set<State> = [start]
            var parent: [State: (State, Int)] = [:]
            var head = 0
            var goal: State?
            while head < queue.count {
                let state = queue[head]
                head += 1
                if state.a == targetA && state.b == targetB { goal = state; break }
                for next in neighbors(of: state.blank) where !blocked.contains(next) {
                    var nextState = state
                    nextState.blank = next
                    if next == state.a {
                        nextState.a = state.blank
                    } else if next == state.b {
                        nextState.b = state.blank
                    }
                    if !visited.contains(nextState) {
                        visited.insert(nextState)
                        parent[nextState] = (state, next)
                        queue.append(nextState)
                    }
                }
            }

            guard let goal else { return }
            var path: [Int] = []
            var current = goal
            while let (previous, move) = parent[current] {
                path.append(move)
                current = previous
            }
            for step in path.reversed() { performMove(step) }
        }

        // Solve all rows except the last two, left to right.
        for row in 0..<(n - 2) {
            for col in 0..<(n - 2) {
                let target = pos(row, col)
                solveOneTile(tileID: target, target: target, blocked: frozen)
                frozen.insert(target)
            }

            let firstID = pos(row, n - 2)
            let secondID = pos(row, n - 1)
            solveTwoTiles(firstID: firstID, secondID: secondID, targetA: firstID, targetB: secondID, blocked: frozen)
            frozen.insert(firstID)
            frozen.insert(secondID)
        }

        // Solve the remaining strip down to its final three columns, column by column.
        for col in 0..<(n - 3) {
            let firstID = pos(n - 2, col)
            let secondID = pos(n - 1, col)
            solveTwoTiles(firstID: firstID, secondID: secondID, targetA: firstID, targetB: secondID, blocked: frozen)
            frozen.insert(firstID)
            frozen.insert(secondID)
        }

        // Solve the final 2x3 block via breadth-first search over its state space.
        let block = [
            pos(n - 2, n - 3), pos(n - 2, n - 2), pos(n - 2, n - 1),
            pos(n - 1, n - 3), pos(n - 1, n - 2), pos(n - 1, n - 1)
        ]
        let adjacency = [[1, 3], [0, 2, 4], [1, 5], [0, 4], [1, 3, 5], [2, 4]]
        let goal = block
        let state = block.map { board[$0] }
        if state != goal {
            var queue: [(state: [Int], path: [Int])] = [(state, [])]
            var visited: Set<[Int]> = [state]
            var head = 0
            while head < queue.count {
                let node = queue[head]
                head += 1
                if node.state == goal {
                    for step in node.path { performMove(step) }
                    break
                }
                let blankIndex = node.state.firstIndex(of: blankID)!
                for nextIndex in adjacency[blankIndex] {
                    var nextState = node.state
                    nextState.swapAt(blankIndex, nextIndex)
                    if !visited.contains(nextState) {
                        visited.insert(nextState)
                        queue.append((nextState, node.path + [block[nextIndex]]))
                    }
                }
            }
        }

        return moves
    }

    /// Solves a 3x3 board directly via breadth-first search over the whole board.
    private func solveWholeBoard(board: [Int], gridSize n: Int) -> [Int] {
        let blankID = n * n - 1
        let goal = Array(0..<(n * n))
        if board == goal { return [] }

        func neighbors(of position: Int) -> [Int] {
            let row = position / n
            let col = position % n
            var result: [Int] = []
            if row > 0 { result.append(position - n) }
            if row < n - 1 { result.append(position + n) }
            if col > 0 { result.append(position - 1) }
            if col < n - 1 { result.append(position + 1) }
            return result
        }

        var queue: [[Int]] = [board]
        var visited: Set<[Int]> = [board]
        var parent: [[Int]: ([Int], Int)] = [:]
        var head = 0
        while head < queue.count {
            let state = queue[head]
            head += 1
            if state == goal {
                var path: [Int] = []
                var current = state
                while let (previous, move) = parent[current] {
                    path.append(move)
                    current = previous
                }
                return path.reversed()
            }
            let blank = state.firstIndex(of: blankID)!
            for next in neighbors(of: blank) {
                var nextState = state
                nextState.swapAt(blank, next)
                if !visited.contains(nextState) {
                    visited.insert(nextState)
                    parent[nextState] = (state, next)
                    queue.append(nextState)
                }
            }
        }
        return []
    }
}
