//
//  ImageSourceImpl.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

protocol ImageSource {
    func fetchImage() async throws -> CGImage
}

/// Tries `primary` first and falls back to `fallback` on any error.
struct ImageSourceImpl: ImageSource {
    private let primary: any ImageSource
    private let fallback: any ImageSource

    init(
        primary: any ImageSource = RemoteImageSource(),
        fallback: any ImageSource = LocalImageSource()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetchImage() async throws -> CGImage {
        do {
            return try await primary.fetchImage()
        } catch {
            return try await fallback.fetchImage()
        }
    }
}
