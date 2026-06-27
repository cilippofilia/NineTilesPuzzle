//
//  WallOfFameStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Observation

/// Persists wall-of-fame card PNGs to the app's Documents directory and vends
/// them back as `CGImage`s. One file per `WallOfFameSlot`, lazily loaded on
/// first access and cached in memory for the session.
@MainActor
@Observable
final class WallOfFameStore {
    private var cache: [WallOfFameSlot: CGImage] = [:]

    private var wallDirectory: URL {
        URL.documentsDirectory.appending(path: "wall_of_fame", directoryHint: .isDirectory)
    }

    init() {
        try? FileManager.default.createDirectory(at: wallDirectory, withIntermediateDirectories: true)
    }

    /// The on-disk URL for `slot`'s PNG — valid to share whenever `cardImage(for:)` returns non-nil.
    func fileURL(for slot: WallOfFameSlot) -> URL {
        wallDirectory.appending(path: "\(slot.fileName).png")
    }

    /// Returns the stored card image for `slot`, or `nil` if no record has been pinned yet.
    func cardImage(for slot: WallOfFameSlot) -> CGImage? {
        if let cached = cache[slot] { return cached }
        let url = wallDirectory.appending(path: "\(slot.fileName).png")
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        cache[slot] = image
        return image
    }

    /// Renders `cgImage` as a PNG and writes it to disk, updating the cache.
    /// The disk write runs on a background executor so it never blocks the main actor.
    func save(_ cgImage: CGImage, for slot: WallOfFameSlot) {
        cache[slot] = cgImage
        let url = wallDirectory.appending(path: "\(slot.fileName).png")
        Task.detached(priority: .utility) {
            let data = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
            else { return }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { return }
            try? (data as Data).write(to: url, options: .atomic)
        }
    }
}
