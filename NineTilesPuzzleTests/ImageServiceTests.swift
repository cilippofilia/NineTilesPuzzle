//
//  ImageServiceTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 5/25/26.
//

import CoreGraphics
import Testing
@testable import NineTilesPuzzle

@Suite("ImageService")
@MainActor
struct ImageServiceTests {

    @Test func fallsBackToLocalOnNetworkError() async throws {
        let service = ImageService(
            primarySource: FailingImageSource(error: URLError(.notConnectedToInternet)),
            fallbackSource: SucceedingImageSource(image: makeTestImage())
        )
        let image = try await service.loadImage()
        #expect(image.width > 0)
    }

    @Test func successfulRemoteFetchReturnsImage() async throws {
        let expected = makeTestImage()
        let service = ImageService(primarySource: SucceedingImageSource(image: expected))
        let image = try await service.loadImage()
        #expect(image.width == expected.width)
        #expect(image.height == expected.height)
    }

    private func makeTestImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 300,
            height: 300,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}

// MARK: - Mock sources

private struct FailingImageSource: ImageSource {
    let error: Error
    func fetchImage() async throws -> CGImage { throw error }
}

private struct SucceedingImageSource: ImageSource {
    let image: CGImage
    func fetchImage() async throws -> CGImage { image }
}
