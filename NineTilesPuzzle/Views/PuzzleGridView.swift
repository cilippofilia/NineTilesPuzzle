//
//  PuzzleGridView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleGridView: View {
    @Environment(PuzzleState.self) private var state
    @State private var tileSize: CGFloat = 0
    @State private var draggingTileID: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(state.tiles) { tile in
                let col = tile.currentIndex % 3
                let row = tile.currentIndex / 3
                if let cgImage = state.tileImages[tile.id] {
                    TileView(
                        tile: tile,
                        image: cgImage,
                        tileSize: tileSize,
                        onDragStarted: { draggingTileID = tile.id },
                        onDragEnded: { point in handleDrop(point, for: tile) }
                    )
                    .offset(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize)
                    .zIndex(draggingTileID == tile.id ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width / 3
        } action: { tileSize = $0 }
        .coordinateSpace(.named("puzzleGrid"))
    }

    private func handleDrop(_ point: CGPoint, for tile: TileModel) {
        draggingTileID = nil
        guard tileSize > 0 else { return }
        let targetCol = min(max(Int(point.x / tileSize), 0), 2)
        let targetRow = min(max(Int(point.y / tileSize), 0), 2)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.swapTiles(from: tile.currentIndex, to: targetRow * 3 + targetCol)
        }
    }
}
