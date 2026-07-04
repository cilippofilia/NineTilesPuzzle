//
//  PuzzleBoardSnapshot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Composites the current arrangement of tile slices into a single PNG for the Live Activity's
/// board preview. Works straight off the tile `CGImage`s rather than rendering a SwiftUI view,
/// so it stays cheap enough to call when a game begins and when the app is backgrounded.
enum PuzzleBoardSnapshot {
    /// One tile's placement: its identity (which slice) and the grid position it currently occupies.
    struct Placement {
        var id: Int
        var position: Int
    }

    /// Renders `placements` into a square PNG. Cells whose tile id matches `blankTileID` are left
    /// as backdrop, so Slide mode's empty cell reads correctly. Returns `nil` if a drawing context
    /// or the PNG encode can't be created.
    static func pngData(
        placements: [Placement],
        images: [Int: CGImage],
        gridSize: Int,
        blankTileID: Int?
    ) -> Data? {
        guard gridSize > 0 else { return nil }

        // Cap the composite at a Lock-Screen-friendly size; the context scales each slice to fit.
        let targetDimension = 600
        let cell = max(1, targetDimension / gridSize)
        let dimension = cell * gridSize

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Dark backdrop so gaps and the blank cell read as background rather than transparent.
        context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))

        for placement in placements {
            guard placement.id != blankTileID, let image = images[placement.id] else { continue }
            let row = placement.position / gridSize
            let col = placement.position % gridSize
            // CGContext's origin is bottom-left; flip the row so grid position 0 lands top-left.
            let y = (gridSize - 1 - row) * cell
            context.draw(image, in: CGRect(x: col * cell, y: y, width: cell, height: cell))
        }

        guard let composited = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, composited, nil)
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }
}
