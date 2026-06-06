//
//  PuzzleGridView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleGridView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(SoundService.self) private var soundService
    @State private var draggingTileID: Int?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let geoWidth = geometry.size.width
                    let calculatedTileSize = geoWidth / CGFloat(state.gridSize)

                    ZStack(alignment: .topLeading) {
                        ForEach(state.tiles) { tile in
                            let col = tile.currentIndex % state.gridSize
                            let row = tile.currentIndex / state.gridSize

                            if let cgImage = state.tileImages[tile.id] {
                                TileView(
                                    tile: tile,
                                    image: cgImage,
                                    tileSize: calculatedTileSize,
                                    onDragStarted: { draggingTileID = tile.id },
                                    onDragEnded: { point in 
                                        handleDrop(point, for: tile, currentTileSize: calculatedTileSize)
                                    }
                                )
                                .frame(width: calculatedTileSize, height: calculatedTileSize)
                                // Use .position with explicit center coordinates for reliable placement
                                .position(
                                    x: (CGFloat(col) * calculatedTileSize) + (calculatedTileSize / 2),
                                    y: (CGFloat(row) * calculatedTileSize) + (calculatedTileSize / 2)
                                )
                                .zIndex(draggingTileID == tile.id ? 1000 : 0)
                            }
                        }
                    }
                }
            }
            .coordinateSpace(.named("puzzleGrid"))
    }

    private func handleDrop(_ point: CGPoint, for tile: TileModel, currentTileSize: CGFloat) {
        draggingTileID = nil
        guard currentTileSize > 0 else { return }

        // Calculate target rows/cols using the geometry-provided tile size passed into the function
        let targetCol = min(max(Int(point.x / currentTileSize), 0), state.gridSize - 1)
        let targetRow = min(max(Int(point.y / currentTileSize), 0), state.gridSize - 1)
        let targetIndex = targetRow * state.gridSize + targetCol
        let didMove = tile.currentIndex != targetIndex

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.swapTiles(from: tile.currentIndex, to: targetIndex)
        }

        if didMove {
            soundService.playTileClick()
        }
    }
}
