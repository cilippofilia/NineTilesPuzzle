//
//  ImageService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import CoreGraphics
import Foundation

@MainActor
final class ImageService {
    private let primarySource: any ImageSource
    private let fallbackSource: any ImageSource

    init(
        primarySource: (any ImageSource)? = nil,
        fallbackSource: (any ImageSource)? = nil
    ) {
        self.primarySource = primarySource ?? ImageSourceFactory.make()
        self.fallbackSource = fallbackSource ?? LocalImageSource()
    }

    func loadImage() async throws -> CGImage {
        do {
            return try await primarySource.fetchImage()
        } catch is URLError {
            return try await fallbackSource.fetchImage()
        }
    }
}
