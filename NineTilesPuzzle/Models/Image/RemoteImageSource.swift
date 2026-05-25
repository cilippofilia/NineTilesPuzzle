//
//  RemoteImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct RemoteImageSource: ImageSource {
    func fetchImage() async throws -> CGImage {
        guard let url = URL(string: "https://picsum.photos/1024") else {
            throw ImageSourceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        
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
