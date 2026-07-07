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
    let gridSize: Int
    let isFogMode: Bool
    let isHinted: Bool
    let hapticsEnabled: Bool
    let debugOverlayEnabled: Bool
    let onDragStarted: () -> Void
    let onDragEnded: (CGPoint) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    /// Sparkle fog: tile is unrevealed and not being touched.
    private var showFog: Bool { isFogMode && !tile.isLocked && !isDragging }
    /// Frosted glass: tile is being actively dragged (can't see what you're placing).
    private var showFrostedGlass: Bool { isFogMode && !tile.isLocked && isDragging }

    var body: some View {
        ZStack {
            TileContentView(image: image, number: tile.id + 1, gridSize: gridSize, tileSize: tileSize)
                .blur(radius: showFog ? 18 : showFrostedGlass ? 3 : 0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .animation(.easeInOut(duration: 1.2), value: tile.isLocked)

            if showFog {
                // Just the darkening scrim here; the animated sparkles for every unrevealed
                // tile are painted together by the board-level `PuzzleFogLayer`.
                Color.black.opacity(0.45)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 1.2), value: tile.isLocked)
        .frame(width: tileSize, height: tileSize)
        .clipShape(.rect)
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.08 : (tile.isCorrect ? 1.0 : 0.98))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile.isCorrect)
        .shadow(radius: isDragging ? 8 : 0)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: tile.isCorrect) { _, newValue in
            newValue && hapticsEnabled
        }
        .overlay {
            if isHinted {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.yellow, lineWidth: 3)
                    .shadow(color: .yellow, radius: 6)
            }
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
/// the number identifying which position the tile belongs at, styled after classic
/// physical sliding-tile puzzles: alternating red/cream tiles with embossed gold numerals.
private struct TileContentView: View {
    let image: CGImage?
    let number: Int
    let gridSize: Int
    let tileSize: CGFloat

    /// Checkerboard alternation keyed off the tile's home position (`number - 1`), not its
    /// current grid slot — on a physical tile puzzle the color is painted on the tile itself.
    private var isAlternateTile: Bool {
        let homeIndex = number - 1
        let row = homeIndex / gridSize
        let col = homeIndex % gridSize
        return (row + col).isMultiple(of: 2)
    }

    var body: some View {
        if let image {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle()
                    .fill(isAlternateTile ? Color.numberedTileRed : Color.numberedTileCream)
                Rectangle()
                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                Text(number, format: .number)
                    .font(.system(size: tileSize * 0.4, design: .serif))
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.numberedTileGoldLight, .numberedTileGoldDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 1, y: 1)
                    .minimumScaleFactor(0.4)
                    .padding(4)
            }
        }
    }
}

private extension Color {
    static let numberedTileRed = Color(red: 0.70, green: 0.15, blue: 0.16)
    static let numberedTileCream = Color(red: 0.94, green: 0.90, blue: 0.78)
    static let numberedTileGoldLight = Color(red: 0.97, green: 0.84, blue: 0.45)
    static let numberedTileGoldDark = Color(red: 0.72, green: 0.55, blue: 0.12)
}

#Preview("Numbered Tiles") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
        ForEach(1...9, id: \.self) { number in
            TileContentView(image: nil, number: number, gridSize: 3, tileSize: 90)
                .frame(width: 90, height: 90)
                .clipShape(.rect(cornerRadius: 6))
        }
    }
    .padding()
}
