//
//  PuzzleState.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
@Observable
final class PuzzleState {
    private let imageService = ImageService()
    private let puzzleEngine = PuzzleEngine()

    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    var isLoading = false
    var isSolved = false
    var error: Error?

    init() {
        restoreFromUserDefaults()
    }

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state.
    func startNewGame() async {
        isLoading = true
        isSolved = false
        error = nil

        do {
            let image = try await imageService.loadImage()
            sourceImage = image

            let slices = ImageSlicer().slice(image)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            let initial = (0..<9).map {
                TileModel(id: $0, currentIndex: $0, isLocked: false)
            }
            tiles = puzzleEngine.shuffle(initial)

            isLoading = false
            saveToUserDefaults()
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Attempts to swap the tiles at `sourceIndex` and `targetIndex`; no-ops if either is locked.
    func swapTiles(from sourceIndex: Int, to targetIndex: Int) {
        guard
            let source = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let target = tiles.first(where: { $0.currentIndex == targetIndex }),
            !source.isLocked,
            !target.isLocked
        else { return }

        puzzleEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        isSolved = puzzleEngine.isSolved(tiles)
        saveToUserDefaults()
    }
}

// MARK: - Persistence

private extension PuzzleState {
    enum Keys {
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
    }

    func saveToUserDefaults() {
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        UserDefaults.standard.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            UserDefaults.standard.set(jpegData, forKey: Keys.sourceImage)
        }
    }

    func restoreFromUserDefaults() {
        guard
            let tilesData = UserDefaults.standard.data(forKey: Keys.tiles),
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData),
            let imageData = UserDefaults.standard.data(forKey: Keys.sourceImage),
            let restoredImage = cgImage(fromJPEG: imageData)
        else { return }

        tiles = restoredTiles
        sourceImage = restoredImage
        let slices = ImageSlicer().slice(restoredImage)
        tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })
        isSolved = puzzleEngine.isSolved(tiles)
    }

    func jpeg(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }

    func cgImage(fromJPEG data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
