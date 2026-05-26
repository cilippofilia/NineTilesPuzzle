//
//  ImageSlicerTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 5/25/26.
//

import CoreGraphics
import Testing
@testable import NineTilesPuzzle

@Suite("ImageSlicer")
struct ImageSlicerTests {
    private let slicer = ImageSlicer()

    private func makeImage(width: Int, height: Int) -> CGImage {
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

    @Test func sliceProducesNineTiles() {
        let tiles = slicer.slice(makeImage(width: 300, height: 300))
        #expect(tiles.count == 9)
    }

    @Test func tileDimensionsAreCorrect() {
        let tiles = slicer.slice(makeImage(width: 300, height: 300))
        for tile in tiles {
            #expect(tile.width == 100)
            #expect(tile.height == 100)
        }
    }

    @Test func sliceHandlesNonSquareImage() {
        let tiles = slicer.slice(makeImage(width: 300, height: 200))
        #expect(tiles.count == 9)
    }
}
