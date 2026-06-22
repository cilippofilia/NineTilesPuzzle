//
//  ImageSourceError.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import Foundation

enum ImageSourceError: Error, LocalizedError {
    case missingBundleResource(String)
    case invalidImageData
    case invalidURL
    case notAuthorized
    case noPhotosAvailable
    case providerUnavailable

    var errorDescription: String? {
        switch self {
        case .missingBundleResource(let name):
            return "The bundle resource '\(name)' could not be found."
        case .invalidImageData:
            return "The image data could not be decoded into a valid image."
        case .invalidURL:
            return "The URL is malformed or could not be constructed."
        case .notAuthorized:
            return "Access to the photo library was denied. Please allow access in Settings."
        case .noPhotosAvailable:
            return "No photos were found in your library."
        case .providerUnavailable:
            return "Seems the image provider is out of service. Switch to photos to continue playing."
        }
    }
}
