//
//  ChallengeStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation
import ImageIO

/// Tracks Challenge Friends history — every challenge sent or received, and the outcome
/// once a received challenge is played. Fully independent of `StatsStore`, like Daily
/// Challenge: challenge results never touch the per-`StatsKey` personal-best tables.
///
/// Metadata (`records`) persists as one JSON blob in `UserDefaults`, mirroring
/// `DailyChallengeStore`. Each challenge's image persists as its own file in
/// `Documents/challenges/<id>.jpg`, mirroring `WallOfFameStore` — the bytes are already a
/// compressed JPEG (`ChallengeImageCodec` output) by the time they reach this store, so
/// no re-encode is needed, just a direct write.
@MainActor
@Observable
final class ChallengeStore {
    /// All modes except Zen are challengeable — Zen has no move/time bests tracked anywhere,
    /// so it has no natural win/lose metric. Gauntlet Ladder runs are excluded separately by
    /// callers (a ladder run isn't a single reproducible puzzle instance).
    static let eligibleGameModes: [GameMode] = GameMode.allCases.filter { $0.isAvailable && $0 != .zen }

    /// Soft cap on retained history — oldest records (and their cached images) are pruned
    /// past this count so storage doesn't grow unbounded over the life of the app.
    static let historyCap = 200

    private let defaults: PersistenceStore

    private(set) var records: [ChallengeRecord] = []

    /// Lazily decoded, session-only cache — mirrors `WallOfFameStore.cache`.
    @ObservationIgnored private var imageCache: [UUID: CGImage] = [:]
    @ObservationIgnored private var pendingDecodes: Set<UUID> = []
    /// Bumped whenever `imageCache` gains an entry, so `image(for:)`'s callers re-query.
    private var revision = 0

    private var challengesDirectory: URL {
        URL.documentsDirectory.appending(path: "challenges", directoryHint: .isDirectory)
    }

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: challengesDirectory, withIntermediateDirectories: true)
        restoreFromUserDefaults()
    }

    private func fileURL(for id: UUID) -> URL {
        challengesDirectory.appending(path: "\(id.uuidString).jpg")
    }

    // MARK: - Recording

    /// Registers a challenge this device just sent, before presenting the share sheet /
    /// Nearby flow. `opponentLabel` is whatever the sender typed to identify the recipient
    /// (there's no read receipt in a no-backend design, so this is cosmetic only).
    func registerSent(_ challenge: FriendChallenge, opponentLabel: String, transport: ChallengeRecord.Transport) {
        try? challenge.imageData.write(to: fileURL(for: challenge.id), options: .atomic)
        let record = ChallengeRecord(
            id: challenge.id,
            direction: .sent,
            opponentName: opponentLabel,
            gameMode: challenge.gameMode,
            gridSize: challenge.gridSize,
            seed: challenge.seed,
            creatorMoves: challenge.senderMoves,
            creatorTime: challenge.senderTime,
            createdAt: challenge.createdAt,
            transport: transport,
            parentChallengeID: challenge.parentChallengeID
        )
        insert(record)
    }

    /// Registers a challenge just received (file opened or nearby payload arrived) —
    /// called immediately, before the user decides to play it, so unplayed invites show up
    /// in history too.
    func registerReceived(_ challenge: FriendChallenge, transport: ChallengeRecord.Transport) {
        guard !records.contains(where: { $0.id == challenge.id }) else { return }
        try? challenge.imageData.write(to: fileURL(for: challenge.id), options: .atomic)
        let record = ChallengeRecord(
            id: challenge.id,
            direction: .received,
            opponentName: challenge.senderName,
            gameMode: challenge.gameMode,
            gridSize: challenge.gridSize,
            seed: challenge.seed,
            creatorMoves: challenge.senderMoves,
            creatorTime: challenge.senderTime,
            createdAt: challenge.createdAt,
            transport: transport,
            parentChallengeID: challenge.parentChallengeID
        )
        insert(record)
    }

    /// Fills in the receiver's own result for a played challenge and computes the outcome.
    /// Returns `nil` if no matching `.received` record exists (shouldn't happen in practice).
    @discardableResult
    func recordCompletion(challengeID: UUID, moves: Int, time: TimeInterval) -> ChallengeRecord.Outcome? {
        guard let index = records.firstIndex(where: { $0.id == challengeID && $0.direction == .received }) else {
            return nil
        }
        let outcome = Self.determineOutcome(
            yourMoves: moves,
            yourTime: time,
            creatorMoves: records[index].creatorMoves,
            creatorTime: records[index].creatorTime
        )
        records[index].opponentMoves = moves
        records[index].opponentTime = time
        records[index].outcome = outcome
        records[index].playedAt = .now
        persistRecords()
        return outcome
    }

    /// Fewer moves wins; ties on moves are broken by time; a full tie is `.tied`.
    static func determineOutcome(
        yourMoves: Int, yourTime: TimeInterval, creatorMoves: Int, creatorTime: TimeInterval
    ) -> ChallengeRecord.Outcome {
        if yourMoves != creatorMoves { return yourMoves < creatorMoves ? .won : .lost }
        if yourTime != creatorTime { return yourTime < creatorTime ? .won : .lost }
        return .tied
    }

    // MARK: - Reading

    /// Reconstructs a full `FriendChallenge` from an unplayed `.received` record, so a
    /// history entry can be reopened and played later, not just at the moment it arrives.
    func pendingChallenge(for record: ChallengeRecord) -> FriendChallenge? {
        guard record.direction == .received, record.outcome == nil,
              let imageData = try? Data(contentsOf: fileURL(for: record.id))
        else { return nil }
        return FriendChallenge(
            id: record.id,
            senderName: record.opponentName,
            gameMode: record.gameMode,
            gridSize: record.gridSize,
            seed: record.seed,
            imageData: imageData,
            senderMoves: record.creatorMoves,
            senderTime: record.creatorTime,
            createdAt: record.createdAt,
            parentChallengeID: record.parentChallengeID
        )
    }

    /// Longest edge of a history row's thumbnail (44pt) at the maximum screen scale —
    /// mirrors `WallOfFameStore.thumbnailMaxPixelSize`. History can hold up to `historyCap`
    /// records, so decoding every row at full camera resolution would keep far more texture
    /// memory alive than a scrolling list ever needs.
    private static let thumbnailMaxPixelSize = 44 * 3

    /// The challenge's image, decoded off the main actor and cached for the session —
    /// mirrors `WallOfFameStore.cardImage(for:)`. Returns `nil` while a decode is in flight;
    /// `revision` bumps to re-invalidate callers once it lands.
    func image(for id: UUID) -> CGImage? {
        _ = revision
        if let cached = imageCache[id] { return cached }
        guard !pendingDecodes.contains(id) else { return nil }
        pendingDecodes.insert(id)
        let url = fileURL(for: id)
        Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = await [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixelSize
            ]
            let image = CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
                CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
            }
            await self.finishImageDecode(for: id, image: image)
        }
        return nil
    }

    private func finishImageDecode(for id: UUID, image: CGImage?) {
        pendingDecodes.remove(id)
        if let image { imageCache[id] = image }
        revision += 1
    }

    func count(direction: ChallengeRecord.Direction) -> Int {
        records.count { $0.direction == direction }
    }

    func count(outcome: ChallengeRecord.Outcome) -> Int {
        records.count { $0.outcome == outcome }
    }

    /// Received challenges that have actually been played (an outcome was recorded).
    var playedReceivedCount: Int {
        records.count { $0.direction == .received && $0.outcome != nil }
    }

    // MARK: - Persistence

    private func insert(_ record: ChallengeRecord) {
        records.insert(record, at: 0)
        pruneHistoryIfNeeded()
        persistRecords()
    }

    /// Removes every history record and its cached image, restoring an empty history state.
    func clearAll() {
        for record in records {
            try? FileManager.default.removeItem(at: fileURL(for: record.id))
        }
        records = []
        imageCache = [:]
        pendingDecodes = []
        persistRecords()
    }

    private func pruneHistoryIfNeeded() {
        guard records.count > Self.historyCap else { return }
        for stale in records.suffix(from: Self.historyCap) {
            try? FileManager.default.removeItem(at: fileURL(for: stale.id))
        }
        records = Array(records.prefix(Self.historyCap))
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Keys.records)
    }

    private func restoreFromUserDefaults() {
        guard let data = defaults.data(forKey: Keys.records),
              let decoded = try? JSONDecoder().decode([ChallengeRecord].self, from: data)
        else { return }
        records = decoded
    }

    private enum Keys {
        static let records = "challenge.records"
    }
}
