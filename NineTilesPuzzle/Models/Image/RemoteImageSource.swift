//
//  RemoteImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

protocol ImageSource {
    func fetchImage() async throws -> CGImage
}

struct RemoteImageSource: ImageSource {
    func fetchImage() async throws -> CGImage {
        guard let url = URL(string: "https://picsum.photos/1024") else {
            throw ImageSourceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // Default URLRequest timeout is 60s — far too long to block on when a bundled
        // fallback image is always available; fail fast and let `ImageService` fall back.
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard
            // Data doesn't bridge to CFData automatically in this context;
            // explicit cast is required.
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageSourceError.invalidImageData
        }
        return image
    }
}
