//
//  ChallengeImageCodec.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import ImageIO
import UniformTypeIdentifiers

/// Encodes/decodes the image embedded in a `FriendChallenge`. Deliberately independent of
/// `GameSession.jpeg(from:)` — callers must always pass a fresh in-memory `CGImage` (e.g.
/// `GameSession.croppedSourceImage` at the moment a challenge is sent), never one that has
/// already round-tripped through a lossy restore path, so a challenge's image never
/// compounds compression loss across two separate encode steps.
enum ChallengeImageCodec {
    static let quality: CGFloat = 0.9

    static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
