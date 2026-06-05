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
    private let puzzleEngine = PuzzleEngine()

    var gridSize: Int = 3
    var imageSourceType: ImageSourceType = .random
    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    var isLoading = false
    var isSolved = false
    var currentStreak: Int = 0
    var allTimeHighStreak: Int = 0
    var isNewRecord: Bool = false
    var error: Error?

    init() {
        restoreFromUserDefaults()
    }

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state.
    func startNewGame() async {
        isLoading = true
        isSolved = false
        isNewRecord = false
        error = nil

        do {
            let source: any ImageSource = switch imageSourceType {
            case .random: RemoteImageSource()
            case .local: PhotoLibraryImageSource()
            case .mixed: Bool.random() ? RemoteImageSource() : PhotoLibraryImageSource()
            }
            let image = try await ImageService(primarySource: source).loadImage()
            sourceImage = image

            let slices = ImageSlicer().slice(image, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            let initial = (0..<gridSize * gridSize).map {
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

    var difficultyLabel: String {
        switch gridSize {
        case 3: "Easy"
        case 4: "Medium"
        case 5: "Hard"
        case 6: "Expert"
        case 7: "Master"
        default: "Insane"
        }
    }

    func setImageSourceType(_ type: ImageSourceType) {
        guard type != imageSourceType else { return }
        imageSourceType = type
        UserDefaults.standard.set(type.rawValue, forKey: Keys.imageSourceType)
    }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize else { return }
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
        isSolved = false
        isNewRecord = false
        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.removeObject(forKey: Keys.tiles)
        UserDefaults.standard.removeObject(forKey: Keys.sourceImage)
    }

    /// Attempts to swap the tiles at `sourceIndex` and `targetIndex`; no-ops if either is locked.
    func swapTiles(from sourceIndex: Int, to targetIndex: Int) {
        guard
            let source = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let target = tiles.first(where: { $0.currentIndex == targetIndex }),
            !source.isLocked,
            !target.isLocked
        else { return }

        let lockedBefore = tiles.filter { $0.isLocked }.count
        puzzleEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        isSolved = puzzleEngine.isSolved(tiles)

        let newlyLocked = tiles.filter { $0.isLocked }.count - lockedBefore
        if newlyLocked > 0 {
            currentStreak += 1
            if currentStreak > allTimeHighStreak {
                allTimeHighStreak = currentStreak
                isNewRecord = true
                UserDefaults.standard.set(allTimeHighStreak, forKey: Keys.allTimeHighStreak)
            }
        } else {
            currentStreak = 0
            isNewRecord = false
        }

        saveToUserDefaults()
    }
}

// MARK: - Persistence

private extension PuzzleState {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let imageSourceType = "puzzle.imageSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let currentStreak = "puzzle.currentStreak"
        static let allTimeHighStreak = "puzzle.allTimeHighStreak"
    }

    func saveToUserDefaults() {
        UserDefaults.standard.set(gridSize, forKey: Keys.gridSize)
        UserDefaults.standard.set(imageSourceType.rawValue, forKey: Keys.imageSourceType)
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        UserDefaults.standard.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            UserDefaults.standard.set(jpegData, forKey: Keys.sourceImage)
        }
        UserDefaults.standard.set(currentStreak, forKey: Keys.currentStreak)
    }

    func restoreFromUserDefaults() {
        let savedSize = UserDefaults.standard.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        allTimeHighStreak = UserDefaults.standard.integer(forKey: Keys.allTimeHighStreak)

        if let rawSource = UserDefaults.standard.string(forKey: Keys.imageSourceType),
           let savedSource = ImageSourceType(rawValue: rawSource) {
            imageSourceType = savedSource
        }

        guard
            let tilesData = UserDefaults.standard.data(forKey: Keys.tiles),
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData),
            let imageData = UserDefaults.standard.data(forKey: Keys.sourceImage),
            let restoredImage = cgImage(fromJPEG: imageData)
        else { return }

        guard restoredTiles.count == gridSize * gridSize else { return }

        tiles = restoredTiles
        sourceImage = restoredImage
        let slices = ImageSlicer().slice(restoredImage, into: gridSize * gridSize)
        tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })
        isSolved = puzzleEngine.isSolved(tiles)
        currentStreak = UserDefaults.standard.integer(forKey: Keys.currentStreak)
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
