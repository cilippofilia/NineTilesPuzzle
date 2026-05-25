//
//  PuzzleState.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
@Observable
class PuzzleState {
    var titles: [TileModel] = []
    var titleImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    var isLoading = false
    var isSolved = false
    var error: Error?

    func startNewGame() async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            sourceImage = try await ImageSourceImpl().fetchImage()
        } catch {
            self.error = error
        }
    }

    func swapTiles(
        from sourceIndex: Int,
        to targetIndex: Int
    ) {
        // temporary empty
    }
}
