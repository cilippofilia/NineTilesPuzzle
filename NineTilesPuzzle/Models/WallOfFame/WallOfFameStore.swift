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
    /// Bumped whenever a card lands in `cache` (a `save()` or a finished background
    /// thumbnail decode). Read at the top of every lazily-caching accessor so views
    /// re-query when new images become available.
    private var revision = 0

    /// Slots with a background thumbnail decode in flight, so `cardImage(for:)` doesn't
    /// spawn a duplicate task on every body re-evaluation while one is already running.
    @ObservationIgnored private var pendingThumbnails: Set<WallOfFameSlot> = []
    /// Filenames present in the wall directory — listed once, then kept in sync by `save()`
    /// and failed decodes. Backs `hasCard(for:)` without a per-slot disk hit.
    @ObservationIgnored private var storedFileNames: Set<String>?

    /// Longest display edge of a pinned card (192pt) at the maximum screen scale — grid
    /// thumbnails are decoded at this size instead of the ~3× capture resolution, which
    /// kept full-size PNG decodes on the main thread mid-scroll and ~5MB of texture
    /// per card alive for the whole visit.
    private static let thumbnailMaxPixelSize = 192 * 3

    private let defaults: PersistenceStore

    /// Slots the player has manually hidden via long-press "Unpin from Wall". The underlying
    /// personal-best record is untouched — this only affects whether its card is drawn.
    private(set) var hiddenFileNames: Set<String> = []
    /// Manual per-section display order the player arranged via long-press "Move Earlier"/
    /// "Move Later", keyed by a section identifier (e.g. "bestMoves") and storing slot
    /// `fileName`s in display order. A slot missing from its section's array (never touched,
    /// or added in a later update) falls back to its canonical position — see `orderedSlots`.
    private(set) var sectionOrder: [String: [String]] = [:]

    private enum CurationKeys {
        static let hiddenSlots = "wallOfFame.hiddenSlots"
        static let sectionOrder = "wallOfFame.sectionOrder"
    }

    private var wallDirectory: URL {
        URL.documentsDirectory.appending(path: "wall_of_fame", directoryHint: .isDirectory)
    }

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: wallDirectory, withIntermediateDirectories: true)
        if let data = defaults.data(forKey: CurationKeys.hiddenSlots),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            hiddenFileNames = decoded
        }
        if let data = defaults.data(forKey: CurationKeys.sectionOrder),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            sectionOrder = decoded
        }
    }

    /// Whether the player has hidden `slot`'s card from the board.
    func isHidden(_ slot: WallOfFameSlot) -> Bool {
        hiddenFileNames.contains(slot.fileName)
    }

    /// Hides (or restores) `slot`'s pinned card. Purely a display preference — the personal
    /// best it represents keeps updating normally underneath.
    func setHidden(_ slot: WallOfFameSlot, hidden: Bool) {
        if hidden {
            hiddenFileNames.insert(slot.fileName)
        } else {
            hiddenFileNames.remove(slot.fileName)
        }
        if let data = try? JSONEncoder().encode(hiddenFileNames) {
            defaults.set(data, forKey: CurationKeys.hiddenSlots)
        }
    }

    /// `canonical` reordered per the player's manual arrangement of `section`, if any.
    func orderedSlots(section: String, canonical: [WallOfFameSlot]) -> [WallOfFameSlot] {
        guard let order = sectionOrder[section], !order.isEmpty else { return canonical }
        let byFileName = Dictionary(uniqueKeysWithValues: canonical.map { ($0.fileName, $0) })
        var seen = Set<String>()
        var result = order.compactMap { fileName -> WallOfFameSlot? in
            guard let slot = byFileName[fileName] else { return nil }
            seen.insert(fileName)
            return slot
        }
        result.append(contentsOf: canonical.filter { !seen.contains($0.fileName) })
        return result
    }

    /// Swaps `slot` with its earlier/later neighbor within `section`'s current order,
    /// persisting the new arrangement. No-ops at either end of the section.
    func move(_ slot: WallOfFameSlot, section: String, canonical: [WallOfFameSlot], earlier: Bool) {
        var order = orderedSlots(section: section, canonical: canonical).map(\.fileName)
        guard let index = order.firstIndex(of: slot.fileName) else { return }
        let targetIndex = earlier ? index - 1 : index + 1
        guard order.indices.contains(targetIndex) else { return }
        order.swapAt(index, targetIndex)
        sectionOrder[section] = order
        if let data = try? JSONEncoder().encode(sectionOrder) {
            defaults.set(data, forKey: CurationKeys.sectionOrder)
        }
    }

    /// The on-disk URL for `slot`'s PNG — valid to share whenever `cardImage(for:)` returns non-nil.
    func fileURL(for slot: WallOfFameSlot) -> URL {
        wallDirectory.appending(path: "\(slot.fileName).png")
    }

    /// Whether a card has ever been captured for `slot` — i.e. `cardImage(for:)` will
    /// eventually return non-`nil`, even if its thumbnail is still decoding. Lets views
    /// distinguish "loading" from "never earned".
    func hasCard(for slot: WallOfFameSlot) -> Bool {
        _ = revision
        if cache[slot] != nil { return true }
        return storedCardFileNames().contains("\(slot.fileName).png")
    }

    /// Returns the stored card image for `slot` at grid-display size, `nil` if no record has
    /// been pinned yet — or `nil` *while a background decode is in flight*, in which case a
    /// `revision` bump re-invalidates the caller once the thumbnail is ready. Decoding
    /// happens off the main actor: 20+ synchronous decodes used to land inside the wall's
    /// first body evaluation, stalling the push transition. The zoom overlay uses
    /// `fullResCardImage(for:)` instead.
    func cardImage(for slot: WallOfFameSlot) -> CGImage? {
        _ = revision
        if let cached = cache[slot] { return cached }
        guard hasCard(for: slot), !pendingThumbnails.contains(slot) else { return nil }
        pendingThumbnails.insert(slot)
        let url = fileURL(for: slot)
        Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = await [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixelSize
            ]
            let image = CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
                CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
            }
            await self.finishThumbnailDecode(for: slot, image: image)
        }
        return nil
    }

    private func finishThumbnailDecode(for slot: WallOfFameSlot, image: CGImage?) {
        pendingThumbnails.remove(slot)
        if let image {
            cache[slot] = image
        } else {
            // Undecodable (corrupt/deleted) file: forget it so `hasCard` stops reporting a
            // card that can never render — otherwise every body pass would retry forever.
            storedFileNames?.remove("\(slot.fileName).png")
        }
        revision += 1
    }

    /// One directory listing, memoized for the session.
    private func storedCardFileNames() -> Set<String> {
        if let storedFileNames { return storedFileNames }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: wallDirectory.path)) ?? []
        let set = Set(names)
        storedFileNames = set
        return set
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
        storedFileNames?.insert("\(slot.fileName).png")
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
