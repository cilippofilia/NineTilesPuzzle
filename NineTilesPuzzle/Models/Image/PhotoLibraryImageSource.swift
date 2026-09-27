//
//  PhotoLibraryImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import Photos
import UIKit

struct PhotoLibraryImageSource: ImageSource {
    /// The player's hand-picked photo pool. Empty means the whole library.
    var selectedIdentifiers: [String] = []

    func fetchImage() async throws -> CGImage {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            throw ImageSourceError.notAuthorized
        }

        let result = fetchCandidateAssets()
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

    /// The picked photos when any still resolve; otherwise every non-screenshot image.
    /// Picked photos that were since deleted — or that fall outside a downgraded
    /// limited-access scope — simply don't come back, and if none survive the whole library
    /// is used rather than failing the game.
    private func fetchCandidateAssets() -> PHFetchResult<PHAsset> {
        if !selectedIdentifiers.isEmpty {
            let selected = PHAsset.fetchAssets(withLocalIdentifiers: selectedIdentifiers, options: nil)
            if selected.count > 0 {
                return selected
            }
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "NOT ((mediaSubtype & %d) == %d)",
            PHAssetMediaSubtype.photoScreenshot.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        return PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }
}
