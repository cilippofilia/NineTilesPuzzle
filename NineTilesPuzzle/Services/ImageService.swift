//
//  ImageService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
final class ImageService {
    private let primarySource: any ImageSource
    private let fallbackSource: any ImageSource

    init(
        primarySource: (any ImageSource)? = nil,
        fallbackSource: (any ImageSource)? = nil
    ) {
        self.primarySource = primarySource ?? RemoteImageSource()
        self.fallbackSource = fallbackSource ?? LocalImageSource()
    }

    /// Loads an image from the primary source, falling back to the local source on any `URLError`.
    func loadImage() async throws -> CGImage {
        do {
            return try await primarySource.fetchImage()
        } catch is URLError {
            return try await fallbackSource.fetchImage()
        }
    }
}
