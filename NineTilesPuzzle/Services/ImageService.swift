//
//  ImageService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct ImageFetchResult {
    let image: CGImage
    /// True when `primarySource` failed and `fallbackSource` had to be used instead.
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
        } catch {
            // A flaky/slow connection doesn't always surface as `URLError` — it can also
            // return truncated data that downloads "successfully" but fails to decode into
            // a `CGImage` (`ImageSourceError.invalidImageData`). Any primary-source failure
            // should fall back, not just network-level ones.
            return ImageFetchResult(image: try await fallbackSource.fetchImage(), usedFallback: true)
        }
    }
}
