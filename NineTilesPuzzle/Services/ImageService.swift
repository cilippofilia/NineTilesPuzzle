//
//  ImageService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct ImageFetchResult {
    let image: CGImage
    /// True when `primarySource` threw a `URLError` and `fallbackSource` had to be used
    /// instead — callers use this to skip behavior that only makes sense for a freshly
    /// fetched remote photo (e.g. the "memorize the image" preview).
    let usedFallback: Bool
}

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

    func loadImage() async throws -> ImageFetchResult {
        do {
            return ImageFetchResult(image: try await primarySource.fetchImage(), usedFallback: false)
        } catch is URLError {
            return ImageFetchResult(image: try await fallbackSource.fetchImage(), usedFallback: true)
        }
    }
}
