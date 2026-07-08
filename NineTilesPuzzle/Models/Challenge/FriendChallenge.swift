//
//  FriendChallenge.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation

/// The self-contained wire payload for Challenge Friends — everything a receiving device
/// needs to reproduce the exact puzzle and show a win/lose comparison, with no backend
/// involved. Identical whether it travels as a shared file or over Multipeer.
///
/// `seed` is minted fresh at share time — it is *not* the sender's own game's shuffle seed,
/// only a value that lets the receiver's board be seeded identically via `SeededShuffle`.
nonisolated struct FriendChallenge: Codable, Equatable, Identifiable, Sendable {
    static let currentFormatVersion = 1

    let id: UUID
    let formatVersion: Int
    let senderName: String
    let gameMode: GameMode
    let gridSize: Int
    let seed: UInt64
    let imageData: Data
    let senderMoves: Int
    let senderTime: TimeInterval
    let createdAt: Date
    /// Set when this challenge is a reply to an earlier one ("Challenge Them Back"),
    /// purely for cosmetic chaining in history — not required to play or score it.
    let parentChallengeID: UUID?

    init(
        id: UUID = UUID(),
        formatVersion: Int = FriendChallenge.currentFormatVersion,
        senderName: String,
        gameMode: GameMode,
        gridSize: Int,
        seed: UInt64,
        imageData: Data,
        senderMoves: Int,
        senderTime: TimeInterval,
        createdAt: Date = .now,
        parentChallengeID: UUID? = nil
    ) {
        self.id = id
        self.formatVersion = formatVersion
        self.senderName = senderName
        self.gameMode = gameMode
        self.gridSize = gridSize
        self.seed = seed
        self.imageData = imageData
        self.senderMoves = senderMoves
        self.senderTime = senderTime
        self.createdAt = createdAt
        self.parentChallengeID = parentChallengeID
    }
}
