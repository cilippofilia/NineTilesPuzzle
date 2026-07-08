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
    /// Both caches are `@ObservationIgnored`: they're filled lazily *during* view body
    /// evaluation (`cardImage`/`heroSlot`), and an observed write there invalidates the
    /// calling view — opening the wall used to re-run its whole body once per stored
    /// card. `revision` below is the observed stand-in that views depend on instead.
    @ObservationIgnored private var cache: [WallOfFameSlot: CGImage] = [:]
    /// When each slot's card was last captured — set optimistically in `save()` so a fresh
    /// capture immediately outranks older ones this session, before the async disk write
    /// lands. Backs `heroSlot(forGridSize:)`.
    @ObservationIgnored private var lastModified: [WallOfFameSlot: Date] = [:]
    /// Bumped by `save()` only. Read at the top of every lazily-caching accessor so views
    /// still re-query when a new record card lands while the wall is visible.
    private var revision = 0

    /// Longest display edge of a pinned card (192pt) at the maximum screen scale — grid
    /// thumbnails are decoded at this size instead of the ~3× capture resolution, which
    /// kept full-size PNG decodes on the main thread mid-scroll and ~5MB of texture
    /// per card alive for the whole visit.
    private static let thumbnailMaxPixelSize = 192 * 3

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

    /// Returns the stored card image for `slot` at grid-display size, or `nil` if no record
    /// has been pinned yet. Decoded eagerly as a thumbnail so first display doesn't trigger
    /// a deferred full-resolution decode mid-scroll; the zoom overlay uses
    /// `fullResCardImage(for:)` instead.
    func cardImage(for slot: WallOfFameSlot) -> CGImage? {
        _ = revision
        if let cached = cache[slot] { return cached }
        let url = fileURL(for: slot)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixelSize
        ]
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        cache[slot] = image
        return image
    }

    /// The full-resolution card for `slot`, decoded from disk on demand — used by the zoom
    /// overlay and nowhere else, so the capture-resolution bitmap is only ever alive while
    /// one card is actually zoomed. Falls back to the in-memory cache for a card captured
    /// this session whose async disk write hasn't landed yet.
    func fullResCardImage(for slot: WallOfFameSlot) -> CGImage? {
        let url = fileURL(for: slot)
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return cache[slot] }
        return image
    }

    /// Renders `cgImage` as a PNG and writes it to disk, updating the cache.
    /// The disk write runs on a background executor so it never blocks the main actor.
    func save(_ cgImage: CGImage, for slot: WallOfFameSlot) {
        cache[slot] = cgImage
        lastModified[slot] = Date()
        revision += 1
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

    /// The instant `slot`'s card was last captured — read from `lastModified` when this
    /// session captured it, otherwise from the PNG's on-disk modification date (memoized
    /// there afterward), so a cold launch still knows what was captured most recently.
    private func lastModifiedDate(for slot: WallOfFameSlot) -> Date? {
        if let known = lastModified[slot] { return known }
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(for: slot).path),
            let date = attributes[.modificationDate] as? Date
        else { return nil }
        lastModified[slot] = date
        return date
    }

    /// The more recently captured of `.bestMoves`/`.bestTime` for `size`, or `nil` if neither
    /// has ever been earned. Lets the Wall of Fame's per-difficulty overview show one
    /// representative "hero" card per grid size instead of duplicating both record categories.
    func heroSlot(forGridSize size: Int) -> WallOfFameSlot? {
        _ = revision
        let candidates: [WallOfFameSlot] = [.bestMoves(gridSize: size), .bestTime(gridSize: size)]
        return candidates
            .compactMap { slot in lastModifiedDate(for: slot).map { (slot, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}
