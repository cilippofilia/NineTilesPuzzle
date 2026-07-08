//
//  ChallengeImageCodecTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/8/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("ChallengeImageCodec")
struct ChallengeImageCodecTests {
    private func makeTestImage(width: Int = 60, height: Int = 60) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test func roundTripPreservesDimensions() throws {
        let original = makeTestImage(width: 120, height: 80)
        let data = try #require(ChallengeImageCodec.encode(original))
        let decoded = try #require(ChallengeImageCodec.decode(data))

        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
    }

    @Test func encodedDataIsValidJPEG() throws {
        let data = try #require(ChallengeImageCodec.encode(makeTestImage()))
        // JPEG files start with the SOI marker 0xFFD8.
        #expect(data.starts(with: [0xFF, 0xD8]))
    }

    @Test func decodeFailsOnGarbageData() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        #expect(ChallengeImageCodec.decode(garbage) == nil)
    }
}
