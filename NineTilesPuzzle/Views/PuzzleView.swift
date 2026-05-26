//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @Environment(PuzzleState.self) private var state
    @State private var tileSize: CGFloat = 0
    @State private var draggingTileID: Int? = nil

    var body: some View {
        @Bindable var state = state

        VStack {
            if state.isLoading {
                LoadingView()
            } else if let error = state.error {
                VStack {
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                    Button("Try again") {
                        Task { await state.startNewGame() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
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
                                onDragEnded: { point in
                                    draggingTileID = nil
                                    guard tileSize > 0 else { return }
                                    let targetCol = min(max(Int(point.x / tileSize), 0), 2)
                                    let targetRow = min(max(Int(point.y / tileSize), 0), 2)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        state.swapTiles(from: tile.currentIndex, to: targetRow * 3 + targetCol)
                                    }
                                }
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
                } action: { newSize in
                    tileSize = newSize
                }
                .coordinateSpace(.named("puzzleGrid"))
            }
        }
        .alert("Puzzle complete!", isPresented: $state.isSolved) {
            Button("Play again") {
                Task { await state.startNewGame() }
            }
        }
    }
}

#Preview {
    PuzzleView()
        .environment(PuzzleState())
}
