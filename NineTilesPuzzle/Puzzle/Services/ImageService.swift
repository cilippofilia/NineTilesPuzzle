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
    func loadImage() async throws -> CGImage {
        do {
            return try await ImageSourceFactory.make().fetchImage()
        } catch is URLError {
            return try await LocalImageSource().fetchImage()
        }
    }
}
