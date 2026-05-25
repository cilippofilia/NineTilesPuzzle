//
//  LocalImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct LocalImageSource: ImageSource {
    func fetchImage() async throws -> CGImage {
        guard let cgImage = UIImage(named: "fallback.jpg")?.cgImage else {
            throw ImageSourceError.missingBundleResource("fallback.jpg")
        }
        return cgImage
    }
}
