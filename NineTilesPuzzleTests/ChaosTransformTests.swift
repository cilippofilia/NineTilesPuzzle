//
//  ChaosTransformTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/26/26.
//

import CoreGraphics
import Testing
@testable import NineTilesPuzzle

@Suite("ChaosTransform")
struct ChaosTransformTests {
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

    @Test func mirrorAndFlipPreserveDimensions() {
        let image = makeImage(width: 300, height: 200)
        for orientation: ChaosTransform.Orientation in [.mirror, .flip, .rotate180] {
            let transform = ChaosTransform(orientation: orientation, tone: .desaturate, posterize: false, pixelate: false)
            let result = transform.apply(to: image, gridSize: 3)
            #expect(result.width == 300)
            #expect(result.height == 200)
        }
    }

    @Test func rotate90And270SwapDimensions() {
        let image = makeImage(width: 300, height: 200)
        for orientation: ChaosTransform.Orientation in [.rotate90, .rotate270] {
            let transform = ChaosTransform(orientation: orientation, tone: .invert, posterize: false, pixelate: false)
            let result = transform.apply(to: image, gridSize: 3)
            #expect(result.width == 200)
            #expect(result.height == 300)
        }
    }

    @Test func everyToneAppliesWithoutChangingDimensions() {
        let image = makeImage(width: 240, height: 240)
        let tones: [ChaosTransform.Tone] = [.desaturate, .invert, .hueShift(angle: .pi / 2), .sepia]
        for tone in tones {
            let transform = ChaosTransform(orientation: .mirror, tone: tone, posterize: false, pixelate: false)
            let result = transform.apply(to: image, gridSize: 4)
            #expect(result.width == 240)
            #expect(result.height == 240)
        }
    }

    @Test func posterizeAndPixelateEachPreserveDimensions() {
        let image = makeImage(width: 240, height: 240)
        let posterizeOnly = ChaosTransform(orientation: .rotate180, tone: .sepia, posterize: true, pixelate: false)
        let pixelateOnly = ChaosTransform(orientation: .rotate180, tone: .sepia, posterize: false, pixelate: true)
        #expect(posterizeOnly.apply(to: image, gridSize: 5).width == 240)
        #expect(pixelateOnly.apply(to: image, gridSize: 5).height == 240)
    }

    @Test func allModifiersStackedStillProducesAnImage() {
        let image = makeImage(width: 240, height: 240)
        let transform = ChaosTransform(orientation: .rotate180, tone: .hueShift(angle: 1.0), posterize: true, pixelate: true)
        let result = transform.apply(to: image, gridSize: 6)
        #expect(result.width == 240)
        #expect(result.height == 240)
    }

    @Test func randomNeverProducesACrashingCombination() {
        let image = makeImage(width: 240, height: 240)
        for _ in 0..<50 {
            let transform = ChaosTransform.random()
            let result = transform.apply(to: image, gridSize: 3)
            #expect(result.width > 0)
            #expect(result.height > 0)
        }
    }
}
