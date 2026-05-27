//
//  ImageSlicer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct ImageSlicer {
    /// Slices `image` into a square grid of `count` tiles (default 9), returned in top-to-bottom reading order.
    func slice(_ image: CGImage, into count: Int = 9) -> [CGImage] {
        let columns = Int(sqrt(Double(count)))
        let rows = columns

        let imgWidth = CGFloat(image.width)
        let imgHeight = CGFloat(image.height)

        // Calculate precise floating-point dimensions per tile
        let tileWidth = imgWidth / CGFloat(columns)
        let tileHeight = imgHeight / CGFloat(rows)

        var tiles: [CGImage] = []

        for row in 0..<rows {
            for col in 0..<columns {
                let cgRow = rows - 1 - row

                let rect = CGRect(
                    x: CGFloat(col) * tileWidth,
                    y: CGFloat(cgRow) * tileHeight,
                    width: tileWidth,
                    height: tileHeight
                )

                if let cropped = image.cropping(to: rect) {
                    tiles.append(cropped)
                } else {
                    tiles.append(blankImage(width: Int(tileWidth), height: Int(tileHeight)))
                }
            }
        }
        return tiles
    }

    private func blankImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}
