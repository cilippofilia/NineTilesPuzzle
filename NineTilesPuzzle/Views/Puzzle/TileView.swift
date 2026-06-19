//
//  TileView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct TileView: View {
    let tile: TileModel
    let image: CGImage?
    let tileSize: CGFloat
    let hapticsEnabled: Bool
    let debugOverlayEnabled: Bool
    let onDragStarted: () -> Void
    let onDragEnded: (CGPoint) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        TileContentView(image: image, number: tile.id + 1)
            .frame(width: tileSize, height: tileSize)
            .clipShape(.rect)
            .offset(dragOffset)
            .scaleEffect(isDragging ? 1.08 : (tile.isCorrect ? 1.0 : 0.98))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile.isCorrect)
            .shadow(radius: isDragging ? 8 : 0)
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: tile.isCorrect) { _, newValue in
                newValue && hapticsEnabled
            }
            .overlay(alignment: .topLeading) {
                if debugOverlayEnabled {
                    Text("\(tile.id + 1)")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                        .padding(4)
                }
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

/// Renders a tile's picture slice, or — in Numbers media mode, where `image` is `nil` —
/// the number identifying which position the tile belongs at.
private struct TileContentView: View {
    let image: CGImage?
    let number: Int

    var body: some View {
        if let image {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle()
                    .fill(.tint.opacity(0.15))
                Text(number, format: .number)
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .minimumScaleFactor(0.4)
                    .padding(4)
            }
        }
    }
}
