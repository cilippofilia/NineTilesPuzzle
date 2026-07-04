//
//  PuzzleBoardSnapshot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders the current arrangement of tile slices into a PNG for the Live Activity's board
/// preview. Uses `ImageRenderer` over a real SwiftUI board so the snapshot matches exactly what
/// the player sees in-game — rounded tiles, small gaps, and Slide's empty cell left dark.
@MainActor
enum PuzzleBoardSnapshot {
    /// One tile's placement: its identity (which slice) and the grid position it currently occupies.
    struct Placement {
        var id: Int
        var position: Int
    }

    /// Renders `placements` into a square PNG, or `nil` if the render/encode fails.
    static func pngData(
        placements: [Placement],
        images: [Int: CGImage],
        gridSize: Int,
        blankTileID: Int?
    ) -> Data? {
        guard gridSize > 0 else { return nil }

        let view = SnapshotBoardView(
            placements: placements,
            images: images,
            gridSize: gridSize,
            blankTileID: blankTileID
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }
}

/// The board laid out for the snapshot: a grid of tile slices in their current positions.
private struct SnapshotBoardView: View {
    let placements: [PuzzleBoardSnapshot.Placement]
    let images: [Int: CGImage]
    let gridSize: Int
    let blankTileID: Int?

    /// Rendered side length in points (scaled ×2 by the renderer). Kept modest — this is only
    /// ever shown as a thumbnail on the Lock Screen and in the Dynamic Island.
    private let side: CGFloat = 240

    var body: some View {
        let tileByPosition = Dictionary(placements.map { ($0.position, $0.id) }) { first, _ in first }
        let spacing: CGFloat = gridSize > 5 ? 1 : 2

        VStack(spacing: spacing) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { column in
                        tile(for: tileByPosition[row * gridSize + column])
                    }
                }
            }
        }
        .padding(spacing)
        .frame(width: side, height: side)
        .background(.black)
    }

    @ViewBuilder
    private func tile(for id: Int?) -> some View {
        Group {
            if let id, id != blankTileID, let cgImage = images[id] {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                // Slide's empty cell (or any gap) reads as a subtle recessed square.
                Color.white.opacity(0.05)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: gridSize > 5 ? 2 : 4))
    }
}
