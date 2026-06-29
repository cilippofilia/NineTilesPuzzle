//
//  PhotoLibraryImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import Photos
import UIKit

struct PhotoLibraryImageSource: ImageSource {
    func fetchImage() async throws -> CGImage {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            throw ImageSourceError.notAuthorized
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "NOT ((mediaSubtype & %d) == %d)",
            PHAssetMediaSubtype.photoScreenshot.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard result.count > 0 else {
            throw ImageSourceError.noPhotosAvailable
        }

        let asset = result[Int.random(in: 0..<result.count)]

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let cgImage = image?.cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: ImageSourceError.invalidImageData)
                }
            }
        }
    }
}
