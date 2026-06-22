//
//  PuzzleGridView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleGridView: View {
    let showReveal: Bool

    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings
    @Environment(SoundService.self) private var soundService
    @State private var draggingTileID: Int?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let geoWidth = geometry.size.width
                    let calculatedTileSize = geoWidth / CGFloat(session.gridSize)

                    ZStack(alignment: .topLeading) {
                        if session.selectedGameMode == .slide {
                            Rectangle()
                                .fill(.quaternary)
                        }

                        ForEach(session.tiles) { tile in
                            let col = tile.currentIndex % session.gridSize
                            let row = tile.currentIndex / session.gridSize
                            let isBlank = session.selectedGameMode == .slide && tile.id == session.tiles.count - 1
                            let cgImage = session.tileImages[tile.id]

                            if !isBlank, session.mediaSourceType == .numbers || cgImage != nil {
                                TileView(
                                    tile: tile,
                                    image: cgImage,
                                    tileSize: calculatedTileSize,
                                    gridSize: session.gridSize,
                                    hapticsEnabled: settings.hapticsEnabled,
                                    debugOverlayEnabled: settings.debugOverlayEnabled,
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

                        if let revealImage = session.croppedSourceImage {
                            Image(decorative: revealImage, scale: 1.0)
                                .resizable()
                                .frame(width: geoWidth, height: geoWidth)
                                .opacity(showReveal ? 1 : 0)
                                .zIndex(2000)
                        }
                    }
                }
            }
            .coordinateSpace(.named("puzzleGrid"))
            .allowsHitTesting(!session.isSolved)
    }

    private func handleDrop(_ point: CGPoint, for tile: TileModel, currentTileSize: CGFloat) {
        draggingTileID = nil
        guard currentTileSize > 0 else { return }

        var didMove = false

        if session.selectedGameMode == .slide {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                didMove = session.slideTile(from: tile.currentIndex)
            }
        } else {
            // Calculate target rows/cols using the geometry-provided tile size passed into the function
            let targetCol = min(max(Int(point.x / currentTileSize), 0), session.gridSize - 1)
            let targetRow = min(max(Int(point.y / currentTileSize), 0), session.gridSize - 1)
            let targetIndex = targetRow * session.gridSize + targetCol
            didMove = tile.currentIndex != targetIndex

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                session.swapTiles(from: tile.currentIndex, to: targetIndex)
            }
        }

        if didMove {
            soundService.playTileClick()
        }
    }
}
