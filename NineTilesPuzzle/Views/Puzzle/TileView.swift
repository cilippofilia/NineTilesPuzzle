//
//  TileView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct TileView: View {
    let tile: TileModel
    let image: CGImage
    let tileSize: CGFloat
    let hapticsEnabled: Bool
    let onDragStarted: () -> Void
    let onDragEnded: (CGPoint) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        Image(decorative: image, scale: 1.0)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .clipShape(.rect)
            .offset(dragOffset)
            .scaleEffect(isDragging ? 1.08 : (tile.isLocked ? 1.0 : 0.98))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile.isLocked)
            .shadow(radius: isDragging ? 8 : 0)
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: tile.isLocked) { _, newValue in
                newValue && hapticsEnabled
            }
            .allowsHitTesting(!tile.isLocked)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("puzzleGrid"))
                    .onChanged { value in
                        dragOffset = value.translation
                        if !isDragging {
                            isDragging = true
                            onDragStarted()
                        }
                    }
                    .onEnded { value in
                        onDragEnded(value.location)
                        resetDragState()
                    }
            )
    }

    private func resetDragState() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
            isDragging = false
        }
    }
}
