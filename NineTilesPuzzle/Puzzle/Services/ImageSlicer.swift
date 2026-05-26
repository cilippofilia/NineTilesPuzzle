//
//  ImageSlicer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import CoreGraphics

struct ImageSlicer {
    /// Slices `image` into a square grid of `count` tiles (default 9), returned in reading order.
    func slice(_ image: CGImage, into count: Int = 9) -> [CGImage] {
        let columns = Int(sqrt(Double(count)))
        let rows = columns
        let tileWidth = image.width / columns
        let tileHeight = image.height / rows

        var tiles: [CGImage] = []
        for row in 0..<rows {
            for col in 0..<columns {
                let rect = CGRect(
                    x: col * tileWidth,
                    y: row * tileHeight,
                    width: tileWidth,
                    height: tileHeight
                )
                tiles.append(image.cropping(to: rect) ?? blankImage(width: tileWidth, height: tileHeight))
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
