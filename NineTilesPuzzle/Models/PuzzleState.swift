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
    let titles: [TileModel]
    let titleImages: [Int: CGImage]
    let sourceImage: CGImage?
    let isLoading: Bool
    let isSolved: Bool
    let error: Error?

    init(
        titles: [TileModel],
        titleImages: [Int : CGImage],
        sourceImage: CGImage?,
        isLoading: Bool,
        isSolved: Bool,
        error: Error?
    ) {
        self.titles = titles
        self.titleImages = titleImages
        self.sourceImage = sourceImage
        self.isLoading = isLoading
        self.isSolved = isSolved
        self.error = error
    }

    func startNewGame() async {
        // temporary empty
    }

    func swapTiles(
        from sourceIndex: Int,
        to targetIndex: Int
    ) {
        // temporary empty
    }
}
